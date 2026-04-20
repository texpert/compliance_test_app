# Milestone 4: AIS Rails Implementation Plan

## Status
- Date: 2026-04-09
- State: Draft approved for implementation
- Source: `docs/salt_edge_compliance_plan.md` (Milestone 4) + implementation planning review

## Objective
Deliver one reproducible AIS happy path in Rails:
1. Create consent
2. Redirect PSU to SCA
3. Handle callback safely
4. Validate consent state
5. Provide endpoints to fetch accounts and transactions (manual action)

The implementation must prioritize traceability, sanitized logging, and testability.

## In Scope
- Rails endpoints and UI for one simple AIS journey
 - Rails endpoints and an explicit operator-driven UI for the AIS journey (see UI notes below)
- Service objects for Salt Edge API communication via `httpx`
- Callback/state validation with replay protection
- Lightweight audit metadata (use existing `Consent` + `Event` models; do not introduce a separate `AisFlowRun` model)
- RSpec coverage for happy path and key failure paths
- Documentation updates for reproducibility

## Out of Scope (for this milestone)
- Broad UX polish beyond the demo flow
- Full production-hardening of every edge case
- Non-AIS product surfaces not required by this journey

## Implementation Checklist

### Phase 1: Contract Freeze and Unknowns
- [ ] Reconfirm endpoint/header contract in `docs/tpp_discovery_notes.md` and `docs/ais_api_checklist.md`
- [ ] Capture canonical TPP/PSU/ASPSP SCA workflow in `docs/knowledge/salt_edge_ais/knowledge.md` and align terms across AIS docs
- [ ] Freeze callback contract (`state`, expected params, success/failure branching)
- [ ] Record unresolved sandbox mismatches in `docs/inconsistencies_and_errors.md`

### Phase 2: Dependency, Configuration, and Core Signing Foundation
- [x] Add `dotenv` support for local configuration (`gem "dotenv"`, dev/test) *(PR #14)*
- [x] Add `ngrok-wrapper` gem for local callback tunneling required by SCA redirects *(PR #14, #32)*
  - [x] Gem source in `Gemfile` (development group only): `gem "ngrok-wrapper"`
  - [x] `gem 'localhost', require: 'localhost/authority'` added to development group for local SSL *(PR #32)*
  - [x] Upstream repository: https://github.com/texpert/ngrok-wrapper
  - [x] Env-toggle contract: `NGROK_TUNNEL` (`true` enables tunnel)
  - [x] Optional ngrok config path env: `NGROK_CONFIG` (default `~/.ngrok2/ngrok.yml`)
  - [x] Optional ngrok inspector env: `NGROK_INSPECT` (`true` enables local inspector)
  - [x] `NGROK_ENABLED` constant defined in `config/application.rb` after `Bundler.require` *(PR #32)*
  - [x] Tunnel started in `config/environments/development.rb` with `persistence: true` *(PR #32)*
  - [x] Puma bound to `ssl://localhost:3000` when `NGROK_ENABLED` (`config/puma.rb`) *(PR #32)*
- [x] Enforce a shared `httpx`-based `HttpxClient` implementation using `Rails.logger` for all logging *(PR #14)*
- [x] Apply namespacing only where domain-specific: *(PR #14, #17)*
  - [x] Keep universal `HttpxClient` un-namespaced
  - [x] Use `SaltEdge` namespace for integration services (`SaltEdge::ConsentService`, `SaltEdge::AccountsService`, etc.)
- [x] Implement `SaltEdge::Config` for strict environment validation (based on `anyway_config` gem) *(PR #14)*
- [x] Implement signing helper (`SaltEdge::SignatureBuilder`) for digest/signature/header canonicalization *(PR #14)*
- [x] Add or refresh `.env.example` with `SE_*` variables and safe placeholders *(PR #14)*
- [x] Extend filtering in `config/initializers/filter_parameter_logging.rb` for secrets/signatures/certs *(PR #14)*

#### Localhost tunneling with `ngrok-wrapper`

To support SCA redirects during local development, the project uses the `ngrok-wrapper` gem to manage an ngrok tunnel. The goal is to make tunneling opt-in (env-controlled) and reproducible.

**Gems required** (`group :development` in `Gemfile`):

```ruby
group :development do
  gem 'localhost', require: 'localhost/authority'  # local SSL for Puma
  gem 'ngrok-wrapper'
end
```

**Env vars** (set in `.env` or shell — see `.env.example`):
- `NGROK_TUNNEL` (default `false`) — when `true`, enables tunnel at server boot
- `NGROK_CONFIG` (default `~/.ngrok2/ngrok.yml`) — ngrok config file path; authtoken should live here
- `NGROK_INSPECT` (default `false`) — when `true`, enables the ngrok web inspector

**`config/application.rb`** — `NGROK_ENABLED` constant defined after `Bundler.require`, available to all subsequent config files:

```ruby
NGROK_ENABLED = Rails.env.development? &&
                (Rails.const_defined?(:Server) || ($PROGRAM_NAME.include?('puma') && Puma.const_defined?(:Server))) &&
                ENV['NGROK_TUNNEL'] == 'true'
```

The server-process guard prevents ngrok from starting during `rspec`, `rake`, or `rails console`.

**`config/environments/development.rb`** — tunnel started before `Rails.application.configure`:

```ruby
if NGROK_ENABLED
  require 'ngrok/wrapper'

  options = { addr: 'https://localhost:3000', persistence: true }
  options[:config]  = ENV.fetch('NGROK_CONFIG', "#{Dir.home}/.ngrok2/ngrok.yml")
  options[:inspect] = ENV['NGROK_INSPECT'] == 'true'

  NGROK_URL = Ngrok::Wrapper.start(options)
  $stdout.puts "[NGROK] tunnel started at #{NGROK_URL}"
  $stdout.puts '[NGROK] inspector at http://127.0.0.1:4040' if ENV['NGROK_INSPECT'] == 'true'
end

Rails.application.configure do
  # ...
  if NGROK_ENABLED
    config.force_ssl = true
    config.hosts << URI.parse(NGROK_URL).host
  end
end
```

`persistence: true` reuses an existing ngrok process across server restarts (state stored alongside the ngrok config file). `addr: 'https://localhost:3000'` is required because Puma serves SSL locally when the tunnel is active.

**`config/puma.rb`** — SSL binding when tunnel is active:

```ruby
if self.class.const_defined?(:NGROK_ENABLED) && NGROK_ENABLED
  bind 'ssl://localhost:3000'
else
  port ENV.fetch("PORT", 3000)
end
```

The `self.class.const_defined?` guard prevents a `NameError` when puma.rb is evaluated before `application.rb` in some boot paths.

**Usage**:

```bash
# enable for a single shell session
NGROK_TUNNEL=true bin/rails server

# or set persistently in .env (never commit)
NGROK_TUNNEL=true
```

**Notes:**
- Keep `NGROK_TUNNEL=false` (the default) to preserve deterministic local startup for CI and other developers.
- The ngrok authtoken must be present in the ngrok config file (`~/.ngrok2/ngrok.yml`) — it is not passed as an env var.

### Phase 3: Service Layer
- [x] Implement Salt Edge request adapter on top of `HttpxClient` with timeout/error normalization *(PR #17)*
- [x] Implement AIS services:
  - [x] `SaltEdge::ConsentService` *(PR #17)*
  - [ ] `SaltEdge::ConsentStatusService`
  - [x] `SaltEdge::AccountsService` — extended with `with_balance:` param (`?withBalance=true`) *(PR #17, #36)*
  - [x] `SaltEdge::TransactionsService` *(PR #17)*
  - [x] `SaltEdge::AccountsFetchService` — upserts `Account` and `AccountBalance` records from upstream *(PR #36)*
  - [x] `SaltEdge::TransactionsFetchService` — fetches and persists `Transaction` records; pagination loop driven by service layer (one page at a time) via `TransactionsService#transactions_page` *(PR #37)*

### Phase 4: ActiveAdmin UI, Provider Management, and State Management

#### Certificate Management (Polymorphic, Secure, and Auditable)
- [x] Create a polymorphic `Certificate` model using Rails Delegated Types to support both CA and QSeal certificates
- [x] Implement asymmetric encryption for private key storage (ActiveRecord::Encryption on `certificates.private_key`)
- [x] Support self-referential chaining for CA hierarchies (parent-child via `certificates.parent_id`)
- [x] Integrate a state machine for certificate lifecycle management (`draft`, `issued`, `revoked`, `expired`)
- [ ] Expose certificate management actions in ActiveAdmin (create, activate, revoke, view chain)
- [x] Ensure all certificate operations are auditable and sensitive data is redacted in logs

This phase uses **ActiveAdmin** (without user authentication/authorization) as the sole UI layer for testing purposes. There is no separate orchestration controller and no dedicated start, callback, or result pages — all operator interactions happen through ActiveAdmin.

- [x] Add `gem "activeadmin"` (3.x) and `gem "dartsass-sprockets"` to `Gemfile`
- [x] Install ActiveAdmin without Devise (no authentication/authorization)
- [x] Add `ngrok-wrapper` integration (see Phase 2) to provide a tunnel from localhost so the Salt Edge sandbox can deliver callback requests to the local dev server

#### Provider pages and actions
- [x] Create an ActiveAdmin `Provider` resource page with custom action items:
  - [x] **Generate QSeal certificate** — action button; hidden when an issued cert has >1 month until expiration *(PR #36)*
  - [x] **Register TPP** — action button; shown when an issued QSeal cert exists **and** provider is not yet registered (`registered_at` nil) *(PR #36)*
  - [x] **Create Consent** — POST action with retry-reuse logic for pending consents with errored last event
  - [x] **Fetch Accounts** — GET form (consent select with status shown + `withBalance` checkbox); visible when a `valid` or `accepted` consent exists; `accepted` consent triggers a live status check before proceeding *(PR #36)*
- [x] Implement `SaltEdge::ProviderRegistrationService` for upstream provider registration
- [x] Implement `QsealCertificateCreator` service callable from the admin UI

#### Consent pages and actions
- Note: consent lifecycle is managed from the **Provider show page** (not a dedicated Consent resource). Consents are displayed in a panel on the Provider show page.
- [ ] Create an ActiveAdmin `Consent` resource (read-only index/show) for direct inspection
- [ ] Create an ActiveAdmin `Event` resource (read-only index/show for audit trail)

#### Account and AccountBalance pages
- [x] `Account` model — identified globally by `resource_id` (no FK to consent or provider); upsert key `resource_id` *(PR #36)*
- [x] `AccountBalance` model — belongs to `account`; upsert key `(account_id, balance_type)` *(PR #36)*
- [x] `ActiveAdmin::Accounts` — index (sorted by `updated_at desc`) + show with balances panel + Transactions panel (20 most recent; link to filtered index) + **Fetch Transactions** member action *(PR #36, #37)*
- [x] `ActiveAdmin::AccountBalances` — show only, hidden from nav (`menu false`) *(PR #36)*

#### Transaction pages and actions
- [x] `Transaction` model — belongs to `account`; `booking_status` (`booked`/`pending`); partial unique index on `(account_id, transaction_id) WHERE transaction_id IS NOT NULL`; pending transactions have no stable ID and are replaced on each fetch *(PR #37)*
- [x] `ActiveAdmin::Transactions` — index (filtered by account, booking_status, date range; sorted by `booking_date desc`) + show with all fields and raw JSON panel *(PR #37)*
- [x] **Fetch Transactions** member action on Account show page — form with consent selector, date range (default 90 days ago → today), booking_status select (both/booked/pending), paginated checkbox; `accepted` consent triggers live status check before proceeding *(PR #37)*

#### AIS workflow models and controllers (pre-ActiveAdmin)
- [x] Create `Consent`, `Event`, and `Provider` models with AIS workflow migration *(PR #15)*
- [x] Add AIS controllers: `AisConsentsController`, `AisAccountsController`, `AisTransactionsController`, `AisCallbacksController` *(PR #16)*
- [x] Implement `AisCallbacks::CallbackProcessor` service with handler chain *(PR #16)*
- [x] Add AIS routes for consents, accounts, transactions, and callback endpoints *(PR #18)*

#### Callback handling
- [x] Add callback endpoint route in `config/routes.rb` (outside ActiveAdmin, as a plain API endpoint) *(PR #18)*
- [x] Enforce callback safety: *(PR #16)*
  - [x] Missing state rejected
  - [x] State mismatch rejected
  - [x] Replay on used state rejected
  - [x] Support multiple callback requests for the same Consent (e.g., `partiallyAuthorised` -> `valid`) and ensure replay detection distinguishes legitimate progression from duplicate replays
  - Note: the test-suite currently seeds a special Event with `event_type: 'replay_marker'` to simulate prior processing for replay-detection tests. There is no production code that automatically writes a `replay_marker` event today — replay markers are inserted by tests or by an external process. Accounts and transactions fetching is intentionally manual and must be triggered via the dedicated endpoints or background jobs; the callback handler only reconciles consent status. If you want automatic marking in production, add an idempotent write (for example: create a `replay_marker` after the first successful callback processing) and cover it with specs.

#### Testing and accessibility
- [ ] Ensure ActiveAdmin pages expose deterministic element IDs for E2E tests and simple curl examples for reviewers

### Phase 5: RSpec Coverage
- [x] Service specs for signing, headers, and response/error mapping *(PR #14, #17)*
- [x] Request specs for end-to-end controller flow *(PR #16)*
- [x] Model specs for state uniqueness and transition validity *(PR #15)*
- [x] Failure/security scenarios: *(PR #16)*
  - [x] Invalid callback params
  - [x] State replay
  - [x] Consent not valid post-callback
  - [ ] Upstream timeout/error handling
- [ ] Sanitization assertions for logs
- Note: data-fetching behavior (accounts and transactions) is covered by dedicated controller request-specs (`spec/requests/ais_accounts_spec.rb` and `spec/requests/ais_transactions_spec.rb`). Callback and consent request specs should focus on callback handling and consent status reconciliation only.

### Phase 6: Documentation and Quality Gate
- [x] Update `README.md` with setup and `SE_*` env contract *(PR #19)*
- [x] Update `docs/ais_flow_sequence.md` with concrete request/response trace *(PR #19)*
- [ ] Update `docs/inconsistencies_and_errors.md` with observed doc vs sandbox behavior
- [x] Update milestone progress in `docs/salt_edge_compliance_plan.md` *(PR #19)*

## Proposed Architecture
- UI layer: ActiveAdmin (no authentication/authorization) for all operator interactions — provider management, consent lifecycle, and data fetching
- Callback layer: plain Rails API endpoint for Salt Edge sandbox callbacks (outside ActiveAdmin)
- Service layer:
  - universal clients in `app/services/` (for example, `HttpxClient`)
  - Salt Edge-specific logic in `app/services/salt_edge/` with namespaced service objects and error normalization
  - `SaltEdge::ProviderRegistrationService` for upstream provider registration
  - QSeal certificate generation service
- Persistence layer: rely on existing `Consent` and `Event` models for state and audit metadata; add `Provider` model for provider management
- Tunneling: `ngrok-wrapper` gem provides localhost tunnel for sandbox callback delivery
- Logging: include upstream request IDs (`x-request-id`), headers and params with redaction

## File-by-File Change Plan
- `Gemfile`
  - Add `gem "dotenv"` in development/test
  - Add `gem "httpx"` if not already present
  - Add `gem "ngrok-wrapper"` for local callback tunnel support
  - Add `gem "activeadmin"` (3.x) and `gem "dartsass-sprockets"` for admin UI (no Devise/authentication)
  - Add `gem "anyway_config"` for typed, validated service configuration
- `.env.example`
  - Define complete `SE_*` contract with placeholders and notes
- `config/initializers/filter_parameter_logging.rb`
  - Add filters for keys, certs, signatures, secrets, auth material
- `config/routes.rb`
  - Mount ActiveAdmin engine
  - Add callback endpoint route (outside ActiveAdmin)
- `app/admin/*`
  - Add ActiveAdmin resource files: `providers.rb`, `consents.rb`, `events.rb`
  - Provider resource: custom actions for QSeal generation and provider registration
  - Consent resource: custom actions for create consent, fetch accounts, fetch transactions
  - Event resource: read-only index/show for audit trail
- `app/controllers/*`
  - Add callback controller for Salt Edge sandbox callbacks (plain API endpoint)
- `app/models/*` and `db/migrate/*`
  - Use `Consent` and `Event` for tracking callback/audit metadata.
- `app/services/salt_edge/*`
  - Add config, signing, client, consent/accounts/transactions services
- `app/services/httpx_client.rb`
  - Shared `httpx` client with `Rails.logger`-based request/response/error logging
- `spec/**/*`
  - Add request, model, and service specs for milestone behavior and protections
- `README.md`
  - Add setup, local env contract, and run/test flow notes
- `docs/ais_flow_sequence.md`
  - Fill reproducible happy-path evidence structure with implementation details

## Environment Variable Contract

### Required (Rails app)
- `SE_API_BASE_URL`
- `SE_CALLBACK_BASE_URL`
- `SE_REDIRECT_URI`

### Conditionally Required
- `SE_CLIENT_ID`
- `SE_CLIENT_SECRET`

### Optional With Defaults
- `SE_HTTP_TIMEOUT_SECONDS` (default: 30)
- `SE_PSU_IP_ADDRESS` (optional unless endpoint requires)
- `NGROK_TUNNEL=false` (optional tunnel toggle; set `true` to enable)
- `NGROK_CONFIG=$HOME/.ngrok2/ngrok.yml` (optional ngrok config path)
- `NGROK_INSPECT` (optional; set `true` to enable ngrok inspector)

### Shell Scripts Only (not read by Rails)
- `SE_QSEAL_CERT_PATH` — path to signed cert file, used by `script/` helpers
- `SE_QSEAL_KEY_PATH` — path to private key file, used by `script/` helpers
- `SE_QSEAL_PUBLIC_KEY_PATH` / `SE_QSEAL_P12_PATH` — supplemental script inputs

**Rails reads QSeal certs from the DB** (`certificates` table, encrypted private key via
ActiveRecord::Encryption). The file-path env vars are not wired into `SaltEdge::Config`.

### Secrets Handling
- Use local env storage only (no secrets in git)
- Keep `.env.example` non-sensitive
- Follow `docs/agents/secrets.md`

## Testing Strategy (RSpec)
- Unit-level: signing and HTTP client behavior
- Integration-level (request specs): full flow transitions and callback handling
- Persistence-level: uniqueness and replay protection on state (implemented using `Consent` and `Event` models)
- Negative paths: malformed callback, failed consent state, upstream errors/timeouts
- Redaction checks: ensure sensitive fields are filtered in logs and stored metadata

## Acceptance Criteria
- One deterministic happy path from consent creation to availability of endpoints to retrieve accounts and transactions (fetching is performed via explicit/manual actions or scheduled jobs; not auto-triggered by the callback)
- Callback handling enforces strict state validation and replay protection
- Request/flow logs are traceable and sanitized
- RSpec suite covers happy path plus key failure/security scenarios
- Docs are current and reproducible for reviewer follow-through

## Risks and Mitigations
- Signature/header mismatch risk
  - Mitigation: isolated signer specs and deterministic canonicalization tests
- Sandbox callback behavior drift
  - Mitigation: centralized callback config + explicit mismatch logging
- Secret leakage risk in logs/docs
  - Mitigation: aggressive parameter filtering and doc hygiene checks
- Registration/certificate readiness dependency
  - Mitigation: keep test flow runnable via stubs while live credentials are pending

## Finalized Decisions
- `ngrok-wrapper` is mandatory in dependencies, but tunnel runtime behavior is optional and env-controlled
- Env vars for tunnel control: `NGROK_TUNNEL`, `NGROK_CONFIG`, `NGROK_INSPECT`
- Keep tunnel disabled by default (`NGROK_TUNNEL=false`) to preserve deterministic local startup
- Use SHA-256 certificate fingerprint for `Signature` `keyId` generation in `SaltEdge::SignatureBuilder`
- Use `/v1/...` endpoint paths as canonical request-path baseline and validate against live sandbox behavior
- `SaltEdge::RequestAdapter` returns a Result object (`SaltEdge::RequestResult`) instead of raising by default

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
- [x] Add `ngrok-wrapper` gem for local callback tunneling required by SCA redirects *(PR #14)*
  - [x] Gem source in `Gemfile`: `gem "ngrok-wrapper"`
  - [x] Upstream repository: https://github.com/texpert/ngrok-wrapper
  - [x] Local checkout: `/Users/Shared/dev/ruby/ngrok-wrapper/`
  - [x] Integration pattern reference: `/Users/Shared/dev/ruby/rails_6_rss_reader/`
  - [x] Env-toggle contract from reference implementation: `NGROK_TUNNEL` (`true` enables tunnel)
  - [x] Optional ngrok config path env: `NGROK_CONFIG` (default `~/.ngrok2/ngrok.yml`)
  - [x] Optional ngrok inspector env: `NGROK_INSPECT` (`true` enables local inspector)
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

Implementation notes:
- Add the gem to `Gemfile` (development only):

```ruby
group :development do
  gem 'ngrok-wrapper'
end
```

- Recommended env vars (already used elsewhere):
  - `NGROK_TUNNEL` (default `false`) — when `true`, enable the tunnel at dev boot
  - `NGROK_CONFIG` (default `~/.ngrok2/ngrok.yml`) — optional config path
  - `NGROK_INSPECT` (default `false`) — when `true`, enables the ngrok inspector

- Example initializer (`config/initializers/ngrok.rb`):

```ruby
if ENV['NGROK_TUNNEL'] == 'true' && Rails.env.development?
  require 'ngrok/wrapper'

  Ngrok::Wrapper.start(
    authtoken: ENV['NGROK_AUTHTOKEN'],
    config: ENV.fetch('NGROK_CONFIG', File.expand_path('~/.ngrok2/ngrok.yml')),
    inspect: ENV['NGROK_INSPECT'] == 'true'
  )

  Rails.logger.info("ngrok tunnel started: #{Ngrok::Wrapper.status}")
end
```

- Usage (local dev):

```bash
# enable tunnel for a single shell
export NGROK_TUNNEL=true
export NGROK_AUTHTOKEN=your_token_here
bin/rails server

# or enable persistently in .env (dev only)
```

- Notes:
  - Keep NGROK_TUNNEL disabled by default to preserve deterministic local startup for CI and reviewers.
  - The initializer above is intentionally minimal — the reference implementation in `/Users/Shared/dev/ruby/rails_6_rss_reader/` provides a production-quality pattern; copy specifics if needed.

### Phase 3: Service Layer
- [x] Implement Salt Edge request adapter on top of `HttpxClient` with timeout/error normalization *(PR #17)*
- [x] Implement AIS services: *(PR #17)*
  - [x] `SaltEdge::ConsentService`
  - [ ] `SaltEdge::ConsentStatusService`
  - [x] `SaltEdge::AccountsService`
  - [x] `SaltEdge::TransactionsService`

### Phase 4: ActiveAdmin UI, Provider Management, and State Management

This phase uses **ActiveAdmin** (without user authentication/authorization) as the sole UI layer for testing purposes. There is no separate orchestration controller and no dedicated start, callback, or result pages — all operator interactions happen through ActiveAdmin.

- [ ] Add `gem "activeadmin"` (3.x) and `gem "dartsass-sprockets"` to `Gemfile`
- [ ] Install ActiveAdmin without Devise (no authentication/authorization):
  - [ ] Run `rails generate active_admin:install --skip-users`
  - [ ] Ensure `config/initializers/active_admin.rb` sets `config.authentication_method = false` and `config.current_user_method = false`
- [ ] Add `ngrok-wrapper` integration (see Phase 2) to provide a tunnel from localhost so the Salt Edge sandbox can deliver callback requests to the local dev server

#### Provider pages and actions
- [ ] Create an ActiveAdmin `Provider` resource page with custom action items:
  - [ ] **Generate QSeal certificate** — action button that invokes the QSeal generation logic (see `docs/qseal_generation_runbook.md`) and displays/stores the result
  - [ ] **Register Provider** — action button that calls the Salt Edge provider registration endpoint via `SaltEdge::ProviderRegistrationService` and records the outcome
- [ ] Implement `SaltEdge::ProviderRegistrationService` for upstream provider registration
- [ ] Implement QSeal certificate generation service (or wrap existing script logic) callable from the admin UI

#### Consent pages and actions
- [ ] Create an ActiveAdmin `Consent` resource with:
  - [ ] Index page listing all consents
  - [ ] Show page displaying consent details, status, and associated events
  - [ ] "Create consent" action button that creates a local Consent and invokes the upstream create flow
  - [ ] "Fetch accounts" action button on consent show page (calls `SaltEdge::AccountsService`, produces `accounts_fetch` Event)
  - [ ] "Fetch transactions" action button on consent show page (calls `SaltEdge::TransactionsService`, produces `transactions_fetch` Event)
- [ ] Create an ActiveAdmin `Event` resource (read-only index/show for audit trail)

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

## Environment Variable Contract (Draft)

### Required
- `SE_API_BASE_URL`
- `SE_QSEAL_CERT_PATH`
- `SE_QSEAL_KEY_PATH`
- `SE_CALLBACK_BASE_URL`
- `SE_REDIRECT_URI`

### Conditionally Required (depends on portal credentials)
- `SE_CLIENT_ID`
- `SE_CLIENT_SECRET`
- `SE_QSEAL_KEY_PASSPHRASE`

### Optional With Defaults
- `SE_HTTP_TIMEOUT_SECONDS` (default via app config)
- `SE_PSU_IP_ADDRESS` (optional unless endpoint requires)
- date-range defaults for transaction queries
- `NGROK_TUNNEL=false` (optional tunnel toggle; set `true` to enable)
- `NGROK_CONFIG=$HOME/.ngrok2/ngrok.yml` (optional ngrok config path)
- `NGROK_INSPECT` (optional; set `true` to enable ngrok inspector)

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
- Follow `/Users/Shared/dev/ruby/rails_6_rss_reader/` env naming for tunnel control: `NGROK_TUNNEL`, `NGROK_CONFIG`, `NGROK_INSPECT`
- Keep tunnel disabled by default (`NGROK_TUNNEL=false`) to preserve deterministic local startup
- Use SHA-256 certificate fingerprint for `Signature` `keyId` generation in `SaltEdge::SignatureBuilder`
- Use `/v1/...` endpoint paths as canonical request-path baseline and validate against live sandbox behavior
- `SaltEdge::RequestAdapter` returns a Result object (`SaltEdge::RequestResult`) instead of raising by default

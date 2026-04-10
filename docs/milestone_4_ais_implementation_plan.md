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
5. Fetch accounts and transactions

The implementation must prioritize traceability, sanitized logging, and testability.

## In Scope
- Rails endpoints and UI for one simple AIS journey
- Service objects for Salt Edge API communication via `httpx`
- Callback/state validation with replay protection
- Lightweight persistence of flow state and audit metadata
- RSpec coverage for happy path and key failure paths
- Documentation updates for reproducibility

## Out of Scope (for this milestone)
- Broad UX polish beyond the demo flow
- Full production-hardening of every edge case
- Non-AIS product surfaces not required by this journey

## Implementation Checklist

### Phase 1: Contract Freeze and Unknowns
- [ ] Reconfirm endpoint/header contract in `docs/tpp_discovery_notes.md` and `docs/ais_api_checklist.md`
- [ ] Freeze callback contract (`state`, expected params, success/failure branching)
- [ ] Record unresolved sandbox mismatches in `docs/inconsistencies_and_errors.md`

### Phase 2: Dependency, Configuration, and Core Signing Foundation
- [ ] Add `dotenv` support for local configuration (`gem "dotenv"`, dev/test)
- [ ] Add `ngrok-wrapper` gem for local callback tunneling required by SCA redirects
  - [ ] Gem source in `Gemfile`: `gem "ngrok-wrapper"`
  - [ ] Upstream repository: https://github.com/texpert/ngrok-wrapper
  - [ ] Local checkout: `/Users/Shared/dev/ruby/ngrok-wrapper/`
  - [ ] Integration pattern reference: `/Users/Shared/dev/ruby/rails_6_rss_reader/`
  - [ ] Env-toggle contract from reference implementation: `NGROK_TUNNEL` (`true` enables tunnel)
  - [ ] Optional ngrok config path env: `NGROK_CONFIG` (default `~/.ngrok2/ngrok.yml`)
  - [ ] Optional ngrok inspector env: `NGROK_INSPECT` (`true` enables local inspector)
- [ ] Enforce a shared `httpx`-based `HttpxClient` implementation using `Rails.logger` for all logging
- [ ] Apply namespacing only where domain-specific:
  - [ ] Keep universal `HttpxClient` un-namespaced
  - [ ] Use `SaltEdge` namespace for integration services (`SaltEdge::ConsentService`, `SaltEdge::AccountsService`, etc.)
- [ ] Implement `SaltEdge::Config` for strict environment validation (based on `anyway_config` gem)
- [ ] Implement signing helper (`SaltEdge::SignatureBuilder`) for digest/signature/header canonicalization
- [ ] Add or refresh `.env.example` with `SE_*` variables and safe placeholders
- [ ] Extend filtering in `config/initializers/filter_parameter_logging.rb` for secrets/signatures/certs

### Phase 3: Service Layer
- [ ] Implement Salt Edge request adapter on top of `HttpxClient` with timeout/error normalization
- [ ] Implement AIS services:
  - [ ] `SaltEdge::ConsentService`
  - [ ] `SaltEdge::ConsentStatusService`
  - [ ] `SaltEdge::AccountsService`
  - [ ] `SaltEdge::TransactionsService`

### Phase 4: Web Flow and State Management
- [ ] Add routes for start, callback, and result pages in `config/routes.rb`
- [ ] Add thin orchestration controller(s) in `app/controllers/`
- [ ] Add flow persistence model (recommended: `AisFlowRun`) and migration
- [ ] Enforce callback safety:
  - [ ] Missing state rejected
  - [ ] State mismatch rejected
  - [ ] Replay on used state rejected

### Phase 5: RSpec Coverage
- [ ] Service specs for signing, headers, and response/error mapping
- [ ] Request specs for end-to-end controller flow
- [ ] Model specs for state uniqueness and transition validity
- [ ] Failure/security scenarios:
  - [ ] Invalid callback params
  - [ ] State replay
  - [ ] Consent not valid post-callback
  - [ ] Upstream timeout/error handling
- [ ] Sanitization assertions for logs

### Phase 6: Documentation and Quality Gate
- [ ] Update `README.md` with setup and `SE_*` env contract
- [ ] Update `docs/ais_flow_sequence.md` with concrete request/response trace
- [ ] Update `docs/inconsistencies_and_errors.md` with observed doc vs sandbox behavior
- [ ] Update milestone progress in `docs/salt_edge_compliance_plan.md`

## Proposed Architecture
- Controller layer: orchestration only
- Service layer:
  - universal clients in `app/services/` (for example, `HttpxClient`)
  - Salt Edge-specific logic in `app/services/salt_edge/` with namespaced service objects and error normalization
- Persistence layer: flow run record for state, consent ID, status progression, callback metadata
- Logging: include flow correlation (`flow_id`) and upstream request IDs (`x-request-id`) with redaction

## File-by-File Change Plan
- `Gemfile`
  - Add `gem "dotenv"` in development/test
  - Add `gem "httpx"` if not already present
  - Add `gem "ngrok-wrapper"` for local callback tunnel support
  - Add `gem "anyway_config"` for typed, validated service configuration
- `.env.example`
  - Define complete `SE_*` contract with placeholders and notes
- `config/initializers/filter_parameter_logging.rb`
  - Add filters for keys, certs, signatures, secrets, auth material
- `config/routes.rb`
  - Add flow routes: start, callback, results
- `app/controllers/*`
  - Add/update controller(s) for start/callback/results orchestration
- `app/models/*` and `db/migrate/*`
  - Add flow run model + migration for auditable callback-safe journey tracking
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
- Persistence-level: uniqueness and replay protection on state
- Negative paths: malformed callback, failed consent state, upstream errors/timeouts
- Redaction checks: ensure sensitive fields are filtered in logs and stored metadata

## Acceptance Criteria
- One deterministic happy path from consent creation to transactions retrieval
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

## Open Decisions to Finalize
1. Flow state storage approach: DB-backed (`AisFlowRun`) vs session-only (recommend DB-backed)
2. Callback routing: separate NOK route vs single callback endpoint with explicit status parsing

## Finalized Decisions
- `ngrok-wrapper` is mandatory in dependencies, but tunnel runtime behavior is optional and env-controlled
- Follow `/Users/Shared/dev/ruby/rails_6_rss_reader/` env naming for tunnel control: `NGROK_TUNNEL`, `NGROK_CONFIG`, `NGROK_INSPECT`
- Keep tunnel disabled by default (`NGROK_TUNNEL=false`) to preserve deterministic local startup
- Use SHA-256 certificate fingerprint for `Signature` `keyId` generation in `SaltEdge::SignatureBuilder`
- Use `/v1/...` endpoint paths as canonical request-path baseline and validate against live sandbox behavior
- `SaltEdge::RequestAdapter` returns a Result object (`SaltEdge::RequestResult`) instead of raising by default

# Salt Edge Compliance Test Task Plan

## Goal
Deliver a Rails demo integration that simulates a simple AIS flow against Salt Edge TPP sandbox, plus evidence artifacts (screenshots/video), public code repository, a high-level functional diagram, and a list of documentation/journey inconsistencies.

## Stack and Scope Assumptions
- Framework: Ruby on Rails.
- HTTP client for external requests: `httpx` gem.
- Use `ngrok-wrapper` gem in local/sandbox runs to expose a temporary external callback URL for SCA redirects.
- Persistence: start minimal; introduce PostgreSQL only if needed for callback state, consent tracking, or reproducible audit logs.
- Environment target: Salt Edge Berlingroup Artea sandbox docs and TPP journey.

## Work Plan (Milestones + Deliverables)

### 0) Priora Portal Registration Prerequisite
- Register at `https://priora.saltedge.com/` before TPP Verifier checks.
- Obtain verifier client credentials (`App-Id`, `App-Secret`) from portal connection details.
- Store credential values only in local secret storage (`.env`, not in git).
- Exit criteria: verifier credentials are available locally and ready for certificate verification calls.

### 1) Portal Investigation and Requirements Baseline
- Read and map portal sections for introduction, certificates, AIS consents, accounts, and transactions endpoints.
- Capture required headers, auth/signature requirements, redirect/callback parameters, and sandbox prerequisites.
- Deliverables:
  - [tpp_discovery_notes.md](tpp_discovery_notes.md)
  - [ais_api_checklist.md](ais_api_checklist.md) (endpoint + method + mandatory headers + expected responses)
- Exit criteria: all AIS happy-path calls and redirects are mapped end-to-end.

### 2) Generate Test eIDAS QSEAL Certificates
- Follow [certificate_generation_guide.md](certificate_generation_guide.md) to generate sandbox-compatible QSEAL assets.
- Record certificate metadata and usage notes without storing sensitive private keys in repo.
- Run TPP Verifier check with PEM certificate string and valid verifier credentials.
- Deliverables:
  - [qseal_generation_runbook.md](qseal_generation_runbook.md)
  - local secure key/cert storage instructions (outside git)
  - `script/tpp_verifier_check.sh` — docs-compliant verifier call script (uses `App-Id`/`App-Secret`, no signing headers)
  - `script/tpp_register_replay_success_shape.sh` — canonical TPP registration replay script (flat payload + byte-stable digest/signature flow)
  - `script/README.md` — per-script endpoint reference
- Exit criteria: certificate chain/fingerprint is ready for TPP registration and verifier call succeeds (`HTTP 200`) with valid credentials.
 - Exit criteria: certificate chain/fingerprint is ready for TPP registration and verifier call succeeds (`HTTP 200`) with valid credentials.

- Status (2026-04-09): COMPLETED (local generation)
- Safe docs view: `docs/tpp_register_artifacts/2026-04-09-texpert/` (extracted, non-secret files)
- Canonical full secret bundle (git-ignored): `./secrets/qseal/guide_2026-04-09-texpert/texpert.zip`
- Local attempt folder (non-repo): `script/attempts/guide_2026-04-09-texpert/texpert/`
- OpenSSL observed: `OpenSSL 3.6.1` on local machine
- Note: verifier call (`script/tpp_verifier_check.sh`) remains pending until valid `App-Id`/`App-Secret` for TPP Verifier are available in environment; prior verifier probes returned `404 TppVerifierClientNotFound` when wrong credentials were used.

### 3) Register TPP in Salt Edge Sandbox
- Complete TPP registration using generated test certificates.
- Configure redirect URI(s) for Rails app callback route(s).
- Confirm whether OAuth credentials for AIS flow are distinct from verifier client credentials, and document both.
- Deliverables:
  - [tpp_registration_log.md](tpp_registration_log.md)
  - environment variable contract (`SE_*` keys) documented in `README.md` later
- Exit criteria: sandbox accepts registration and app can reach auth entrypoint for AIS consent flow.

Status (2026-04-09): API submission accepted, async validation pending
- The canonical `bg_register.rb` submission from `script/attempts/guide_2026-04-09-texpert` received HTTP `200` with message: "Request is processed. We will send the response to branzeanu.aurel+tpp@gmail.com". Capture: X-Request-ID `39df37c4-54f5-40ec-942e-5d850b1cc7f0`.
- Artifacts archived (safe docs view) at `docs/tpp_register_artifacts/2026-04-09-texpert/` (analysis.md + README). The canonical full secret bundle is stored in the repo-level git-ignored `./secrets/qseal/guide_2026-04-09-texpert/texpert.zip`.
- Final certificate validity is subject to Priora async validation email; await confirmation before proceeding to verifier + AIS flow.

### 4) Build Rails Demo App for AIS Flow
- Implement minimal user journey:
  - 4.1 Create consent
  - 4.2 Redirect PSU to SCA
  - 4.3 Simulate/pass SCA in sandbox
  - 4.4 Handle redirect back/callback
  - 4.5 Fetch accounts and transactions
- Use service objects for external API interactions via `httpx` (e.g., `ConsentService`, `AccountsService`, `TransactionsService`).
- Keep UI simple (single flow page + result pages); focus on compliance journey traceability.
- Add lightweight request/flow logging (sanitize secrets).
- Deliverables:
  - runnable Rails app code
  - [ais_flow_sequence.md](ais_flow_sequence.md) (step-by-step with request/response notes)
- Exit criteria: one repeatable happy path from consent creation to transactions fetch.

Status (2026-04-09): Planning completed, implementation pending
- Detailed execution plan: [milestone_4_ais_implementation_plan.md](milestone_4_ais_implementation_plan.md)

### 5) Produce High-Level Functional Diagram
- Create a system diagram covering actors: PSU, TPP, ASPSP, IDS.
- Include functional blocks: consent management, account services, TPP certificate verification, ASPSP reports, ASPSP dashboard, sandbox management.
- Deliverables:
  - [functional_diagram.md](functional_diagram.md)
  - diagram file (`docs/diagrams/open_banking_system.png` or `.drawio`)
- Exit criteria: diagram explains responsibilities and inter-service interactions clearly.

### 6) Final Evidence and Handoff Package
- Capture proof of AIS flow (screenshots + short screen recording).
- Publish code to public repository for review.
- Document discovered inconsistencies/errors between docs and actual TPP journey.
- Deliverables:
  - [ais_flow_evidence.md](ais_flow_evidence.md)
  - [inconsistencies_and_errors.md](inconsistencies_and_errors.md)
  - final `README.md` with setup and run instructions
- Exit criteria: reviewer can reproduce and validate the flow and findings.

## Risks and Mitigations
- Certificate or registration blockers: keep a troubleshooting log with timestamps and portal references.
- Redirect/callback mismatch: freeze callback contract early and test with deterministic `state` handling.
- Undocumented sandbox behavior: record observed behavior in inconsistencies list with exact endpoint and payload context.

## Suggested Execution Order
1. Priora registration and verifier credential retrieval
2. Investigation and checklists
3. QSEAL generation + verifier check
4. TPP registration
5. Rails flow implementation
6. Diagram and documentation
7. Evidence capture and final delivery

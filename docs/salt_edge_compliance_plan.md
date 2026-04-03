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

### 1) Portal Investigation and Requirements Baseline
- Read and map portal sections for introduction, certificates, AIS consents, accounts, and transactions endpoints.
- Capture required headers, auth/signature requirements, redirect/callback parameters, and sandbox prerequisites.
- Deliverables:
  - `docs/tpp_discovery_notes.md`
  - `docs/ais_api_checklist.md` (endpoint + method + mandatory headers + expected responses)
- Exit criteria: all AIS happy-path calls and redirects are mapped end-to-end.

### 2) Generate Test eIDAS QSEAL Certificates
- Follow `Certificate Generation Guide.pdf` to generate sandbox-compatible QSEAL assets.
- Record certificate metadata and usage notes without storing sensitive private keys in repo.
- Deliverables:
  - `docs/qseal_generation_runbook.md`
  - local secure key/cert storage instructions (outside git)
- Exit criteria: certificate chain/fingerprint is ready for TPP registration.

### 3) Register TPP in Salt Edge Sandbox
- Complete TPP registration using generated test certificates.
- Configure redirect URI(s) for Rails app callback route(s).
- Deliverables:
  - `docs/tpp_registration_log.md`
  - environment variable contract (`SE_*` keys) documented in `README.md` later
- Exit criteria: sandbox accepts registration and app can reach auth entrypoint for AIS consent flow.

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
  - `docs/ais_flow_sequence.md` (step-by-step with request/response notes)
- Exit criteria: one repeatable happy path from consent creation to transactions fetch.

### 5) Produce High-Level Functional Diagram
- Create a system diagram covering actors: PSU, TPP, ASPSP, IDS.
- Include functional blocks: consent management, account services, TPP certificate verification, ASPSP reports, ASPSP dashboard, sandbox management.
- Deliverables:
  - `docs/functional_diagram.md`
  - diagram file (`docs/diagrams/open_banking_system.png` or `.drawio`)
- Exit criteria: diagram explains responsibilities and inter-service interactions clearly.

### 6) Final Evidence and Handoff Package
- Capture proof of AIS flow (screenshots + short screen recording).
- Publish code to public repository for review.
- Document discovered inconsistencies/errors between docs and actual TPP journey.
- Deliverables:
  - `docs/ais_flow_evidence.md`
  - `docs/inconsistencies_and_errors.md`
  - final `README.md` with setup and run instructions
- Exit criteria: reviewer can reproduce and validate the flow and findings.

## Risks and Mitigations
- Certificate or registration blockers: keep a troubleshooting log with timestamps and portal references.
- Redirect/callback mismatch: freeze callback contract early and test with deterministic `state` handling.
- Undocumented sandbox behavior: record observed behavior in inconsistencies list with exact endpoint and payload context.

## Suggested Execution Order
1. Investigation and checklists
2. QSEAL generation
3. TPP registration
4. Rails flow implementation
5. Diagram and documentation
6. Evidence capture and final delivery

# Salt Edge Compliance Test Task Plan

## Goal
Deliver a Rails demo integration that simulates a simple AIS (Account Information Services) flow against the Salt Edge TPP (Third-Party Provider) sandbox, plus evidence artifacts (screenshots/video), public code repository, a high-level functional diagram, and a list of documentation/journey inconsistencies.

## Stack and Scope Assumptions
- Framework: Ruby on Rails.
- HTTP client for external requests: `httpx` gem.
- Use `ngrok-wrapper` gem in local/sandbox runs to expose a temporary external callback URL for SCA (Strong Customer Authentication) redirects.
- Persistence: SQLite (Rails default); sufficient for callback state, consent tracking, and reproducible audit logs at demo scale.
- Environment target: Salt Edge Berlin Group Artea sandbox docs and TPP journey.

## Work Plan (Milestones + Deliverables)

### 0) Priora Portal Registration Prerequisite
- Register at `https://priora.saltedge.com/`.
- Exit criteria: Priora portal registration is complete and the app is visible in the portal.

### 1) Portal Investigation and Requirements Baseline
- Read and map portal sections for introduction, certificates, AIS consents, accounts, and transactions endpoints.
- Capture required headers, auth/signature requirements, redirect/callback parameters, and sandbox prerequisites.
- Deliverables:
  - [tpp_discovery_notes.md](tpp_discovery_notes.md)
  - [ais_api_checklist.md](ais_api_checklist.md) (endpoint + method + mandatory headers + expected responses)
- Exit criteria: all AIS happy-path calls and redirects are mapped end-to-end.

### 2) Generate Test eIDAS (electronic IDentification, Authentication and trust Services) QSEAL (Qualified Electronic Seal) Certificates
- Follow [certificate_generation_guide.md](certificate_generation_guide.md) to generate sandbox-compatible QSEAL assets.
- Record certificate metadata and usage notes without storing sensitive private keys in repo.
- Deliverables:
  - [qseal_generation_runbook.md](qseal_generation_runbook.md)
  - local secure key/cert storage instructions (outside git)
  - `script/archives/tpp_register_replay_success_shape.sh` — archived replay script (flat payload + byte-stable digest/signature flow; investigation reference only)
  - `script/README.md` — per-script endpoint reference
- Exit criteria: certificate chain/fingerprint is ready for TPP registration.

- Status (2026-04-09): COMPLETED (local generation)
- Safe docs view: `docs/tpp_register_artifacts/2026-04-09-texpert/` (extracted, non-secret files)
- Canonical full secret bundle (git-ignored): `./secrets/qseal/guide_2026-04-09-texpert/texpert.zip`
- Local attempt folder (non-repo): `script/attempts/guide_2026-04-09-texpert/texpert/`
- OpenSSL observed: `OpenSSL 3.6.1` on local machine

### 3) Register TPP in Salt Edge Sandbox
- Complete TPP registration using generated test certificates.
- Configure redirect URI values for Rails app callback route(s).
- Deliverables:
  - [tpp_registration_log.md](tpp_registration_log.md)
  - environment variable contract (`SE_*` keys) documented in `README.md` later
- Exit criteria: sandbox accepts registration and app can reach auth entrypoint for AIS consent flow.

Status (2026-04-09): API submission accepted, async validation pending
- The canonical `bg_register.rb` submission from `script/attempts/guide_2026-04-09-texpert` received HTTP `200` with message: "Request is processed. We will send the response to branzeanu.aurel+tpp@gmail.com". Capture: X-Request-ID `39df37c4-54f5-40ec-942e-5d850b1cc7f0`.
- Artifacts archived (safe docs view) at `docs/tpp_register_artifacts/2026-04-09-texpert/` (analysis.md + README). The canonical full secret bundle is stored in the repo-level git-ignored `./secrets/qseal/guide_2026-04-09-texpert/texpert.zip`.
- Final certificate validity is subject to Priora async validation email; await confirmation before proceeding to AIS flow.

### 4) Build Rails Demo App for AIS Flow
- Implement minimal user journey:
  - 4.1 Create consent
  - 4.2 Redirect PSU (Payment Service User) to SCA
  - 4.3 PSU completes SCA in sandbox
  - 4.4 Handle redirect back/callback
  - 4.5 Provide endpoints to fetch accounts and transactions (manual action; callbacks do not auto-fetch data)
- Use service objects for external API interactions via `httpx` (e.g., `ConsentService`, `AccountsService`, `TransactionsService`).
- Keep UI focused and explicit: provide a "Create consent" action (button) that navigates to a consent show page. The consent show page should expose explicit actions (buttons) to "Fetch accounts" and "Fetch transactions". This makes the flow operator-driven and avoids automatic data retrieval during callback handling.

  Consider using ActiveAdmin for the demo admin UI:
  - Pros: very fast to scaffold an admin interface, provides resource listing, show pages and action buttons out of the box, RBAC and filters for demo inspection.
  - Cons: adds a dependency and a different UI stack (admin-focused) rather than a lightweight custom page. May be overkill if you prefer a tiny bespoke UI.
  Recommendation: Use ActiveAdmin for rapid iteration and demoing (especially useful for reviewers), or implement minimal custom pages if you want zero extra dependencies.
- Add lightweight request/flow logging (sanitize secrets).
- Deliverables:
  - runnable Rails app code
  - [ais_flow_sequence.md](ais_flow_sequence.md) (step-by-step with request/response notes)
- Exit criteria: one repeatable happy path from consent creation to availability of endpoints to retrieve accounts and transactions (fetching is manual and must be triggered explicitly).

Status (2026-04-21): Implementation in progress
- Detailed execution plan: [milestone_4_ais_implementation_plan.md](milestone_4_ais_implementation_plan.md)
- Completed (PRs #14–#36): signing infrastructure, request adapter, consent service, accounts/transactions services, callback handling, QSeal cert management, TPP registration, consent creation flow with retry reuse, accounts fetch with `withBalance` support, `Account`/`AccountBalance` models and admin pages, pre-fetch accepted consent status check
- Remaining: dedicated Consent and Event admin resources, transaction fetch admin action

### 5) Produce High-Level Functional Diagram
- Create a system diagram covering actors: PSU, TPP, ASPSP (Account Servicing Payment Service Provider), IDS (Salt Edge internal actor term; confirm exact expansion in portal docs).
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

Status (2026-04-21): In progress
- Public repository: https://github.com/texpert/compliance_test_app
- `ais_flow_evidence.md` populated with proof checklist (all steps verified against Artea sandbox on 2026-04-20), screenshot naming convention, and reviewer notes; operator screenshots/video to be captured separately.
- `inconsistencies_and_errors.md` finalized with 8 findings (4 open, 2 resolved, 2 pending external response).
- `README.md` expanded with full reviewer-ready setup guide, operator AIS flow walkthrough, component table, and documentation map.
- Remaining: operator screenshot/video capture (`docs/evidence/` folder); final PR merge to main.

## Risks and Mitigations
- Certificate or registration blockers: keep a troubleshooting log with timestamps and portal references.
- Redirect/callback mismatch: freeze callback contract early and test with deterministic `state` handling.
- Undocumented sandbox behavior: record observed behavior in inconsistencies list with exact endpoint and payload context.

## Suggested Execution Order
1. Priora registration
2. Investigation and checklists
3. QSEAL generation
4. TPP registration
5. Rails flow implementation
6. Diagram and documentation
7. Evidence capture and final delivery

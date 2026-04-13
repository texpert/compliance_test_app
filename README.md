# Salt Edge Compliance Demo (AIS)

## Overview
This repository hosts a Rails demo integration for Salt Edge AIS flow simulation and supporting documentation.

## Branching Workflow
- Keep `main` stable.
- Implement changes on dedicated feature branches.
- Open PRs from feature branches into `main`.

## Stack
- Ruby `3.4.9` via `mise` (`.tool-versions`).
- Rails `8.1.3`.
- RSpec (`rspec-rails`) for tests.

## Rails Scope (Current)
The app intentionally does not load these frameworks yet:
- `active_storage`
- `action_cable`
- `action_text`
- `action_mailbox`
- `rails/test_unit`

See commented `require` lines in `config/application.rb`.

## Quick Start
```bash
mise install
bundle install
bin/rails db:prepare
```

## Run Locally
```bash
bin/rails server
```

## Run Tests
```bash
bin/rspec
```

## Documentation Map
- Plan: `docs/salt_edge_compliance_plan.md`
- Portal discovery notes: `docs/tpp_discovery_notes.md`
- AIS endpoint checklist: `docs/ais_api_checklist.md`
- QSEAL certificate guide: `docs/certificate_generation_guide.md`
- QSEAL runbook: `docs/qseal_generation_runbook.md`
- Local QSEAL storage policy: `docs/local_qseal_storage.md`
- TPP registration log: `docs/tpp_registration_log.md`
- Priora API changelog: `docs/priora_api_changelog.md`
- Script helpers (register/verifier troubleshooting): `script/README.md`
- AIS flow sequence: `docs/ais_flow_sequence.md`
- Functional diagram notes: `docs/functional_diagram.md`
- Diagram source: `docs/diagrams/open_banking_system.drawio`
- AIS evidence log: `docs/ais_flow_evidence.md`
- Inconsistencies/errors log: `docs/inconsistencies_and_errors.md`

## Milestone 4 (AIS Flow) Index
- Detailed implementation plan: `docs/milestone_4_ais_implementation_plan.md`
- Execution trace template and run notes: `docs/ais_flow_sequence.md`
- Master milestone tracking: `docs/salt_edge_compliance_plan.md`

## Callback processing

Incoming ASPSP callbacks are handled by `AisCallbacks::CallbackProcessor`.
The processor is responsible for validating callback parameters, recording a single incoming `callback` Event
for audit purposes, and delegating to handler classes that perform outgoing upstream requests.

# Fetching accounts and transactions
- Accounts and transactions are not fetched automatically by the callback handler anymore; the `AuthorizationCallbackHandler` now only reconciles consent status. Fetching of accounts and transactions should be triggered manually (for example, via a background job or operator-initiated endpoint) and will produce `accounts_fetch` and `transactions_fetch` Events when executed.

- Testing note: fetching behavior has dedicated controller specs (`spec/requests/ais_accounts_spec.rb` and `spec/requests/ais_transactions_spec.rb`). Callback and consent request specs intentionally do not exercise accounts/transactions fetching — they focus on callback validation and consent status transitions.

## Environment Variables
Copy `.env.example` to `.env` and fill the `SE_*` values required for sandbox integration.

For QSEAL paths, use local file locations outside this repository (for example under `$HOME/secrets/...`) as described in `docs/local_qseal_storage.md`.

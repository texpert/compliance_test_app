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

## Environment Variables
Copy `.env.example` to `.env` and fill the `SE_*` values required for sandbox integration.

For QSEAL paths, use local file locations outside this repository (for example under `$HOME/secrets/...`) as described in `docs/local_qseal_storage.md`.

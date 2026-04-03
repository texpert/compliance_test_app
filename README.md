# Salt Edge Compliance Demo (AIS)

## Overview
This repository contains planning and execution artifacts for a demo TPP integration against Salt Edge sandbox to simulate a simple AIS flow:
1. Create consent
2. Redirect to SCA
3. Pass SCA
4. Handle callback
5. Fetch accounts and transactions

## Current Repository Status
- Project is in documentation-first bootstrap stage.
- App source code and Rails manifests are not added yet.
- Primary execution plan: `docs/salt_edge_compliance_plan.md`.

## Documentation Map
- Plan: `docs/salt_edge_compliance_plan.md`
- Portal discovery notes: `docs/tpp_discovery_notes.md`
- AIS endpoint checklist: `docs/ais_api_checklist.md`
- QSEAL certificate guide (source PDF): `docs/Certificate Generation Guide.pdf`
- QSEAL certificate runbook: `docs/qseal_generation_runbook.md`
- TPP registration log: `docs/tpp_registration_log.md`
- AIS run sequence: `docs/ais_flow_sequence.md`
- Functional diagram notes: `docs/functional_diagram.md`
- Diagram source file: `docs/diagrams/open_banking_system.drawio`
- AIS evidence log: `docs/ais_flow_evidence.md`
- Inconsistencies and errors log: `docs/inconsistencies_and_errors.md`

## Stack and Scope Assumptions
- Rails app for demo implementation.
- `httpx` gem for external API calls.
- `ngrok-wrapper` gem should be integrated into the Rails app for temporary public callback URLs in local/sandbox runs.
- PostgreSQL only if needed for callback/consent/audit persistence.

## Recommended Fill-In Order
1. `docs/tpp_discovery_notes.md`
2. `docs/ais_api_checklist.md`
3. `docs/qseal_generation_runbook.md`
4. `docs/tpp_registration_log.md`
5. `docs/ais_flow_sequence.md`
6. `docs/functional_diagram.md` + `docs/diagrams/open_banking_system.drawio`
7. `docs/ais_flow_evidence.md`
8. `docs/inconsistencies_and_errors.md`

## Setup Placeholder (To Be Confirmed Once Rails App Exists)
Record the exact commands after app bootstrap and dependency setup are committed.

```bash
# TODO: add verified setup commands after Rails app is initialized
# Example placeholders only:
# bundle install
# bin/rails db:prepare
```

## Run Placeholder (To Be Confirmed Once Endpoints Exist)
Record verified local run steps after implementing AIS endpoints/callback flow.
Do not treat `ngrok-wrapper` as a separate manual CLI step; integrate it into the app startup/configuration, similar to `/Users/Shared/dev/ruby/rails_6_rss_reader`.

```bash
# TODO: add verified run commands after app routes/services are implemented
# Example placeholders only:
# bin/rails server
# NGROK tunnel should be started by the app in development when enabled
```

## Environment Contract
For local sandbox setup, copy `.env.example` to `.env` and fill `SE_*` values.

Example `.env` (fake values, for structure only):

```dotenv
SE_ENVIRONMENT=sandbox
SE_API_BASE_URL=https://priora.saltedge.com
SE_CLIENT_ID=demo_client_id
SE_CLIENT_SECRET=demo_secret_if_issued
SE_QSEAL_CERT_PATH=config/certs/qseal_cert.pem
SE_QSEAL_KEY_PATH=config/certs/qseal_key.pem
SE_QSEAL_KEY_PASSPHRASE=demo_passphrase
SE_CERT_FINGERPRINT=AA:BB:CC:DD:EE:FF
SE_CALLBACK_BASE_URL=https://abc123.ngrok-free.app
SE_CALLBACK_PATH=/salt_edge/callback
SE_REDIRECT_URI=https://abc123.ngrok-free.app/salt_edge/callback
SE_HTTP_TIMEOUT_SECONDS=30
```

Required for first AIS happy-path run:
- `SE_ENVIRONMENT` (use `sandbox`)
- `SE_API_BASE_URL` (Salt Edge base URL)
- `SE_CLIENT_ID` (from TPP registration)
- `SE_QSEAL_CERT_PATH` (local cert path)
- `SE_QSEAL_KEY_PATH` (local key path)
- `SE_CALLBACK_BASE_URL` (public URL exposed by the app-integrated ngrok tunnel)
- `SE_CALLBACK_PATH` (callback route in app)
- `SE_REDIRECT_URI` (must match registered callback URL)

Optional/conditional:
- `SE_CLIENT_SECRET` (only if issued by sandbox registration)
- `SE_QSEAL_KEY_PASSPHRASE` (if your key is encrypted)
- `SE_CERT_FINGERPRINT` (needed when sandbox flow/headers require it)
- `SE_HTTP_TIMEOUT_SECONDS` (request timeout tuning)

## Progress Tracking
- Evidence of successful flow: `docs/ais_flow_evidence.md`
- Mismatches/errors found during integration: `docs/inconsistencies_and_errors.md`

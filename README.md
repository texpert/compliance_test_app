# Salt Edge Compliance Demo (AIS)

## Overview

A Rails demo integration that simulates an end-to-end AIS (Account Information Services) flow
against the Salt Edge TPP (Third-Party Provider) Artea sandbox using the Berlin Group XS2A API.
The app covers: TPP registration, consent creation, PSU SCA, callback handling, account fetch,
and transaction fetch.

## Stack

- Ruby `3.4.9` via `mise` (`.tool-versions`)
- Rails `8.1.3`
- SQLite 3 (database)
- RSpec (`rspec-rails`) for tests
- ActiveAdmin for the operator/demo UI

## Setup

### 1. Install runtime and dependencies

```bash
mise install          # installs Ruby 3.4.9 via mise
bundle install
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and fill in the `SE_*` values. The required keys are:

| Variable | Description |
|---|---|
| `SE_API_BASE_URL` | `https://priora.saltedge.com` |
| `SE_CALLBACK_BASE_URL` | Public base URL for ASPSP callbacks (ngrok URL or server URL) |

### 3. Set up ActiveRecord Encryption

The app encrypts the QSEAL private key at rest using Rails ActiveRecord Encryption. Each
environment needs encryption keys stored in its credentials file.

**If you have the project's `.key` files** (obtained securely), place them at
`config/credentials/development.key` and `config/credentials/test.key` — then skip to step 4.

**If starting fresh**, generate and install encryption keys for each environment:

```bash
# 1. Generate keys (prints an active_record_encryption: block — copy the output)
bin/rails db:encryption:init

# 2. Paste the block into each environment's credentials file
bin/rails credentials:edit --environment development
bin/rails credentials:edit --environment test
```

The credentials editor opens `$EDITOR`. Paste the `active_record_encryption:` block, save, and
exit. Repeat for each environment. The resulting `.key` files are git-ignored; keep them safe.

### 4. Prepare the database

```bash
bin/rails db:prepare
```

### 5. (Optional) Expose a public callback URL with ngrok

The Artea sandbox must reach your `/callback/:id` endpoint. Use ngrok for tunnelling:

```bash
ngrok http 3000
# Copy the https:// URL into SE_CALLBACK_BASE_URL in .env
```

### 6. Start the server

```bash
bin/rails server
```

Admin UI is at `http://localhost:3000/admin` — default credentials are set via the database seed
or the first `AdminUser` record.

## Running the AIS Flow (Operator Guide)

The full step-by-step trace with request/response examples is in `docs/ais_flow_sequence.md`.
The abbreviated happy path is:

### Step 1 — Create Consent

1. Open `/admin/providers` and click the registered TPP provider record.
2. Click **Create Consent** on the Provider show page.
3. The app signs and POSTs `/consents` to Salt Edge; a new Consent record appears with status
   `accepted` and an `upstream_consent_id`.

### Step 2 — Get SCA Redirect URL (manual)

> **Note**: The `POST /consents` response does not include `_links.scaRedirect` in the Artea
> sandbox (inconsistency #7). The SCA URL must be retrieved from the Priora portal.

1. Open the Priora portal → Artea sandbox → Consents → find the authorisation record.
2. Copy the `redirect_url` value.
3. Open it in a browser.

### Step 3 — PSU Completes SCA

1. The Artea SCA page prompts for PSU credentials (available on the Artea sandbox credentials
   page in the portal — do not commit them).
2. Approve the consent.
3. The sandbox redirects the browser to `${SE_CALLBACK_BASE_URL}/callback/:consent_id`.

### Step 4 — Callback Handling

The app's callback controller (`GET /callback/:id`) automatically:
- Calls `GET /consents/{upstream_id}/status`
- Updates the local Consent status to `valid`
- Records `callback` and `consent_status_check` Events

### Step 5 — Fetch Accounts

1. On the Provider show page, click **Fetch Accounts**.
2. Select the `valid` consent; optionally check **withBalance**.
3. Submit. Accounts (and balances if requested) are upserted in SQLite.
4. View results at `/admin/accounts`.

### Step 6 — Fetch Transactions

1. Open an Account show page (`/admin/accounts/:id`).
2. Click **Fetch Transactions**.
3. Select a consent, date range, and booking status; submit.
4. Transactions are upserted (booked) or recreated (pending).
5. View results in the Transactions panel on the Account show page or at `/admin/transactions`.

## Run Tests

```bash
bin/rspec
```

## Environment Variables

Full variable reference is in `.env.example`. The QSEAL private key is stored encrypted in the
database (see Setup step 3 for encryption key setup); no file-path env vars are needed by Rails.

## Known Sandbox Deviations

Eight inconsistencies between Salt Edge documentation and observed Artea sandbox behavior are
documented in `docs/inconsistencies_and_errors.md`. The most significant ones affecting the
operator flow:

- **`POST /consents` returns no `scaRedirect`** — SCA URL must be copied from the portal manually.
- **Callback includes no `state`/`code`** — consent correlation uses the path parameter only.
- **Consent status `accepted`** — Artea uses `accepted` where Berlin Group spec says `received`.

## Architecture

See `docs/functional_diagram.md` for the system diagram (Mermaid + drawio source).

Key components:

| Component | Path | Role |
|---|---|---|
| `ConsentService` | `app/services/salt_edge/consent_service.rb` | Creates and status-checks consents |
| `AccountsService` | `app/services/salt_edge/accounts_service.rb` | Fetches accounts and balances |
| `TransactionsService` | `app/services/salt_edge/transactions_service.rb` | Fetches and persists transactions |
| `SigningService` | `app/services/salt_edge/signing_service.rb` | Signs requests with QSEAL (rsa-sha256) |
| `CallbackProcessor` | `app/services/ais_callbacks/callback_processor.rb` | Validates and routes ASPSP callbacks |
| Admin UI | `app/admin/` | ActiveAdmin resources for all entities |

## Documentation Map

| Document | Path |
|---|---|
| Compliance plan | `docs/salt_edge_compliance_plan.md` |
| Portal discovery notes | `docs/tpp_discovery_notes.md` |
| AIS endpoint checklist | `docs/ais_api_checklist.md` |
| QSEAL certificate guide | `docs/certificate_generation_guide.md` |
| QSEAL runbook | `docs/qseal_generation_runbook.md` |
| Local QSEAL storage policy | `docs/local_qseal_storage.md` |
| TPP registration log | `docs/tpp_registration_log.md` |
| Priora API changelog | `docs/priora_api_changelog.md` |
| Script helpers | `script/README.md` |
| AIS flow sequence (request/response trace) | `docs/ais_flow_sequence.md` |
| Functional diagram | `docs/functional_diagram.md` |
| Diagram source (drawio) | `docs/diagrams/open_banking_system.drawio` |
| AIS flow evidence | `docs/ais_flow_evidence.md` |
| Inconsistencies and errors | `docs/inconsistencies_and_errors.md` |
| Milestone 4 implementation plan | `docs/milestone_4_ais_implementation_plan.md` |

## Branching Workflow

- Keep `main` stable.
- Implement changes on dedicated feature branches.
- Open PRs from feature branches into `main`.

## Rails Scope

The app intentionally does not load these frameworks:
`active_storage`, `action_cable`, `action_text`, `action_mailbox`, `rails/test_unit`.
See commented `require` lines in `config/application.rb`.

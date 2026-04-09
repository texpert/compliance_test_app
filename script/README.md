# Script Helpers

These scripts support Salt Edge sandbox troubleshooting and are intentionally split by endpoint.

## External originals

- `script/originals/bg_cert_gen.sh` and `script/originals/bg_register.rb` are the files as received from Salt Edge support, saved from the **local machine**.
- They are immutable references; for runnable experiments, copy and patch in a new external attempt folder.
- `bg_register.rb` is a **standalone Ruby script** — keep patched copies standalone too; do not absorb `SignatureHelper` into Rails app classes.
- Per-attempt sync policy lives in `docs/qseal_generation_runbook.md` and each concrete run is logged in `docs/tpp_registration_log.md`.

### Dual-location snapshot policy

Originals live in two places:

| Location | Purpose |
|----------|---------|
| `script/originals/` | Canonical working reference (always current) |
| `docs/tpp_register_artifacts/YYYY-MM-DD-originals-snapshot/` | Date-stamped read-only snapshot for long-term diffing |

When a new version of either original arrives: update `script/originals/`, then create a **new** date-stamped snapshot folder in `docs/tpp_register_artifacts/`. Never edit existing snapshots.

## `tpp_register_signature_diagnostics.sh`
- Purpose: test signature-header variants against `tpp/register`.
- Uses: same signed registration payload, with multiple `Signature` canonicalization variants.

## `tpp_register_replay_success_shape.sh`
- Purpose: replay the historical successful `tpp/register` request shape.
- Uses: flat payload contract, DN-style `keyId`, `headers="digest date x-request-id"`, and PEM-base64 `TPP-Signature-Certificate`.
- Note: this is the canonical replay helper for future certificate option experiments.

## `tpp_verifier_check.sh`
- Purpose: call `POST /api/tpp_verifiers/v2/certificates`.
- Uses: `App-Id` / `App-Secret` headers and `{ "data": { "certificate": "PEM..." } }` request body.
- Does **not** use registration signature headers.

## Prerequisites
- Populate `.env` from `.env.example`.
- Ensure certificate paths in `.env` point to local files outside git.
- For one-off retries against a fresh attempt folder, you can override QSEAL paths inline without editing `.env`:
  - `SE_QSEAL_CERT_PATH=/abs/path/client_signed_certifcate.crt`
  - `SE_QSEAL_KEY_PATH=/abs/path/client_private.key`
  - `SE_QSEAL_PUBLIC_KEY_PATH=/abs/path/client_public.key`

## Run
```bash
script/tpp_register_signature_diagnostics.sh
script/tpp_register_replay_success_shape.sh
script/tpp_verifier_check.sh
```

# Secrets Handling

Use this file as the single source of truth for secret material in this repository.

## What Counts as a Secret
- `.env` and `.env.*` runtime config files (except `.env.example`).
- Rails key files, including `config/master.key` and other `config/*.key` files.
- Certificate private key material and related artifacts, especially under `config/certs/`:
  - `*.key`, `*.pem`, `*.p12`, `*.pfx`, `*.csr`
- Sensitive credential values loaded via `SE_*` variables (client secrets, passphrases, private-key paths).

## Repository Rules
- Do not commit secrets to git.
- Keep `.env.example` as template-only (no real values).
- Keep certificate and key files local; store only non-sensitive docs/runbooks in `docs/`.

## Enforcement and References
- Ignore rules are defined in `.gitignore` (`.env*`, `config/*.key`, `config/certs/*`, key/cert extensions).
- Certificate handling workflow: `docs/qseal_generation_runbook.md`.
- Local-only QSEAL storage instructions: `docs/local_qseal_storage.md`.
- Environment-variable shape: `.env.example` and `README.md`.

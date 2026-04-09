# Secrets Handling

Use this file as the single source of truth for secret material in this repository.

## What Counts as a Secret
- `.env` and `.env.*` runtime config files (except `.env.example`).
- Rails key files, including `config/master.key` and other `config/*.key` files.
- Certificate private key material and related artifacts, especially under `config/certs/`:
  - `*.key`, `*.pem`, `*.p12`, `*.pfx`, `*.csr`, `*.srl`

  - Note: `*.srl` files (CA serial files) are sensitive state used by OpenSSL/CA tooling and must not be committed to the repository. Keep them only in local, git-ignored secret folders (for example `./secrets/qseal/`).
- Sensitive credential values loaded via `SE_*` variables (client secrets, passphrases, private-key paths).

## Repository Rules
- Do not commit secrets to git.
- Keep `.env.example` as template-only (no real values).
- Keep certificate and key files local; store only non-sensitive docs/runbooks in `docs/`.
-- Generated public key artifacts (for example `./secrets/qseal/guide_2026-04-04/client_public.key`) are non-secret but should remain local unless a portal explicitly requires upload/sharing.
-- For QSEAL generation runs, use a unique folder per attempt (`./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>`). Do not overwrite an existing attempt folder.

## Enforcement and References
- Ignore rules are defined in `.gitignore` (`.env*`, `config/*.key`, `config/certs/*`, key/cert extensions).
- Certificate handling workflow: [qseal_generation_runbook.md](../qseal_generation_runbook.md).
- Local-only QSEAL storage instructions: [local_qseal_storage.md](../local_qseal_storage.md).
- Environment-variable shape: `.env.example` and `README.md`.

# Local QSEAL Storage Instructions

This guide defines how to store QSEAL artifacts locally, outside git, for Milestone 2 and later TPP registration.

## Policy
- Never store key/cert artifacts in this repository.
- Keep certificate artifacts in a user-private folder outside the repo.
- Keep passphrases out of shell history and out of tracked files.
- Use a new attempt folder for every generation run; do not overwrite previous attempt folders.

## Recommended Local Paths
Prefer a repo-level, git-ignored `./secrets/qseal/` folder to store canonical local test artifacts. This keeps local test data available to the team while still excluded from git.
- Root folder: `./secrets/qseal/`
- Attempt folder: `./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/`
- Private key: `./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_private.key`
- Certificate: `./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_signed_certifcate.crt`
- Public key: `./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_public.key`
- CA certificate: `./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/ca_certificate.crt`

## Permissions
Apply strict permissions after creating files:

```bash
chmod 700 "./secrets/qseal"
chmod 700 "./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>"
chmod 600 "./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_private.key"
chmod 600 "./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_signed_certifcate.crt"
chmod 600 "./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/ca_certificate.crt"
```

## Shell Script Usage
The shell scripts in `script/` read cert/key files directly and use `SE_QSEAL_CERT_PATH`,
`SE_QSEAL_KEY_PATH`, and `SE_QSEAL_PUBLIC_KEY_PATH` from `.env`. Set these to the attempt
folder paths (example only):

```bash
SE_QSEAL_CERT_PATH=./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_signed_certifcate.crt
SE_QSEAL_KEY_PATH=./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_private.key
SE_QSEAL_PUBLIC_KEY_PATH=./secrets/qseal/guide_YYYY-MM-DD-<attempt-tag>/client_public.key
```

**The Rails app does not read certs from files.** Certificate PEM and private key are stored in
the `certificates` table (private key encrypted via ActiveRecord::Encryption) and injected into
`SaltEdge::SignatureBuilder` at call time.

Do not commit `.env` and never commit real key material.

## Backup and Recovery
- Keep one encrypted backup copy in an approved local password manager or encrypted volume.
- Record only metadata (fingerprint, serial, validity) in project docs.
- On suspected key exposure, rotate immediately: generate a new keypair, update sandbox registration, invalidate old certificate.

## Local Hygiene Checklist
- `git status` does not show key/cert files.
- No key material appears in shell history.
- No secrets are present in `docs/` files.

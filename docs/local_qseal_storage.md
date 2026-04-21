# Local QSEAL Storage Instructions

> **Scope**: This guide covers storage of QSEAL artifacts for the **TPP registration phase** only
> (certificate generation and `tpp/register` submission). The Rails app does **not** read certs
> from local files — it reads from the `certificates` DB table, with the private key encrypted via
> ActiveRecord::Encryption. See `README.md` Setup step 3 for encryption key setup.

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

The TPP registration investigation scripts (`tpp_register_replay_success_shape.sh`,
`tpp_register_signature_diagnostics.sh`) have been archived to `script/archives/`. They are no
longer part of the active workflow. The `SE_QSEAL_*` and `SE_TPP_*` variables they required have
been removed from `.env.example`; a snapshot of those variables is preserved in
`script/archives/env.example.snapshot` for reference.

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

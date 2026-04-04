# Local QSEAL Storage Instructions

This guide defines how to store QSEAL artifacts locally, outside git, for Milestone 2 and later TPP registration.

## Policy
- Never store key/cert artifacts in this repository.
- Keep certificate artifacts in a user-private folder outside the repo.
- Keep passphrases out of shell history and out of tracked files.

## Recommended Local Paths
Use a path under your home directory:
- Folder: `~/secrets/saltedge/qseal/`
- Private key: `~/secrets/saltedge/qseal/qseal_private.key`
- Certificate: `~/secrets/saltedge/qseal/qseal_cert.pem`
- Bundle: `~/secrets/saltedge/qseal/qseal_bundle.p12`
- Run-specific public key (for portal registration/upload): `~/secrets/saltedge/qseal/guide_2026-04-04/client_public.key`

## Permissions
Apply strict permissions after creating files:

```bash
chmod 700 "$HOME/secrets/saltedge/qseal"
chmod 600 "$HOME/secrets/saltedge/qseal/qseal_private.key"
chmod 600 "$HOME/secrets/saltedge/qseal/qseal_cert.pem"
chmod 600 "$HOME/secrets/saltedge/qseal/qseal_bundle.p12"
```

## Environment Variable Usage
Set local `.env` values to external paths (example only):

```bash
SE_QSEAL_CERT_PATH=$HOME/secrets/saltedge/qseal/qseal_cert.pem
SE_QSEAL_KEY_PATH=$HOME/secrets/saltedge/qseal/qseal_private.key
SE_QSEAL_P12_PATH=$HOME/secrets/saltedge/qseal/qseal_bundle.p12
```

Do not commit `.env` and never commit real passphrases.

## Backup and Recovery
- Keep one encrypted backup copy in an approved local password manager or encrypted volume.
- Record only metadata (fingerprint, serial, validity) in project docs.
- On suspected key exposure, rotate immediately: generate a new keypair, update sandbox registration, invalidate old certificate.

## Local Hygiene Checklist
- `git status` does not show key/cert files.
- No key material appears in shell history.
- No secrets are present in `docs/` files.

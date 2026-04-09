TPP Register Artifacts Index

This folder contains dated archives of past TPP registration attempts. Each subfolder is safe-copied to exclude private keys and other secrets.

Entries:
- 2026-04-04-success-vs-2026-04-06-latest/
- 2026-04-07-originals-snapshot/
- 2026-04-09-texpert/ (canonical Texpert attempt)

Notes:
- Private keys (*.key), CSRs (*.csr), P12/PFX files, and .env secrets are excluded from the safe archives. If you need a full raw archive including private artifacts, keep it in the repository-level git-ignored `secrets` folder: `./secrets/qseal/` (preferred). Older workflows used `$HOME/secrets/saltedge/qseal/`; that legacy location has been removed from developer machines and is no longer used.

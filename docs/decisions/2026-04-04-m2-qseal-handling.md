# Decision: Milestone 2 QSEAL Handling Strategy

**Date**: 2026-04-04
**Status**: Accepted
**Milestone**: 2 - Generate Test eIDAS QSEAL Certificates

## Context
Milestone 2 requires generating sandbox-compatible QSEAL artifacts and recording enough metadata for TPP registration while preserving the repository secret-handling policy.

## Decision
Use an OpenSSL-based local workflow that generates key, CSR, and test certificate artifacts outside the repository (preferred location: repository-level, git-ignored `./secrets/qseal/`).

For sandbox-issued certificates, import and locally verify the CA chain before registration.

Store only non-secret metadata in repository docs:
- SHA-256 fingerprint
- Serial number
- Validity period
- Subject and policy OIDs (including PSD2 OIDs)
- OpenSSL version used for generation/inspection

Never store private keys, passphrases, or PKCS#12 contents in git.

## Rationale
- Meets Milestone 2 deliverables with reproducible steps.
- Aligns with `docs/agents/secrets.md` and existing ignore rules.
- Keeps TPP registration preparation practical while minimizing leak risk.

## Consequences
- `.env` values should point to local paths outside the repository; prefer the repo-level, git-ignored `./secrets/` folder for canonical local test artifacts.
- Team members must provision their own local secure storage before certificate generation.
- If the sandbox requires an issuer chain, chain import and local verification become mandatory before registration.

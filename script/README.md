# Script Helpers

## Active scripts

### `bg_cert_gen.sh`
Generates a local QSEAL certificate chain (CA + client). Follow
`docs/qseal_generation_runbook.md` for the full step-by-step procedure.

### `bg_register.rb`
Submits the TPP registration payload to `POST /api/berlingroup/v1/tpp/register`.
Standalone Ruby script — keep patched copies standalone; do not absorb into Rails app classes.

### `archive_attempt.sh`
Archives a completed QSEAL generation attempt into `script/archives/`.

## Archived investigation scripts

The following scripts were used during the TPP registration investigation and are no longer
part of the normal workflow. They are preserved in `script/archives/` for audit reference:

| Script | Purpose |
|---|---|
| `archives/tpp_register_replay_success_shape.sh` | Replays the historical successful `tpp/register` request shape (DN-style keyId, flat payload) |
| `archives/tpp_register_signature_diagnostics.sh` | Tests multiple `Signature` header canonicalization variants against `tpp/register` |
| `archives/tpp_verifier_check.sh` | Called `POST /api/tpp_verifiers/v2/certificates` — not used; TPP Verifier was not part of the final flow |

An `archives/env.example.snapshot` captures the `.env` variables the archived scripts required
(`SE_QSEAL_*`, `SE_TPP_*`). Those variables have been removed from the live `.env.example`.

## External originals

- `script/originals/bg_cert_gen.sh` and `script/originals/bg_register.rb` are the files as
  received from Salt Edge support. They are immutable references; for runnable experiments, copy
  and patch in a new external attempt folder.
- Per-attempt sync policy lives in `docs/qseal_generation_runbook.md`.
- Concrete runs are logged in `docs/tpp_registration_log.md`.

### Dual-location snapshot policy

| Location | Purpose |
|---|---|
| `script/originals/` | Canonical working reference (always current) |
| `docs/tpp_register_artifacts/YYYY-MM-DD-originals-snapshot/` | Date-stamped read-only snapshot for long-term diffing |

When a new version of either original arrives: update `script/originals/`, then create a new
date-stamped snapshot folder in `docs/tpp_register_artifacts/`. Never edit existing snapshots.

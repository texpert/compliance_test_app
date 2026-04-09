# Originals Snapshot — 2026-04-07

Verbatim copies of the two files received from Salt Edge support and stored
on the local machine before being committed to the repository.

## Source
- **Origin**: Salt Edge support (received externally, saved to local machine)
- **Committed to repo**: `script/originals/` (immutable reference)
- **This folder**: long-term diff snapshot; content must never diverge from
  `script/originals/` at the time of capture.

## Files

| File | Purpose |
|------|---------|
| `bg_cert_gen.sh` | Bash script that generates a self-signed QSeal certificate chain |
| `bg_register.rb` | Standalone Ruby script that signs and POSTs the TPP registration payload |

## Usage rules
- These files are **read-only** reference copies.
- To experiment: copy into a new external attempt folder and patch the copy there.
- For the Ruby registration flow, keep patched copies as standalone scripts
  (do **not** absorb `SignatureHelper` into Rails app classes).
- When a new version of either original is received, create a **new** date-stamped
  snapshot folder alongside this one; do not edit existing snapshots.

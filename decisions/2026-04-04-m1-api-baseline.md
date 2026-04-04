# Decision: Milestone 1 API Baseline Strategy

**Date**: 2026-04-04
**Status**: Accepted
**Milestone**: 1 — Portal Investigation and Requirements Baseline

## Context

Milestone 1 requires populating `docs/tpp_discovery_notes.md` and `docs/ais_api_checklist.md` as
the AIS flow baseline before generating certificates (M2) and registering the TPP (M3). Direct
portal access to confirm Salt Edge Berlingroup / Artea sandbox-specific behaviour (base URL,
SCA UX, exact callback params) is not available at this stage.

## Decision

Treat the Berlin Group NextGenPSD2 XS2A Framework 1.3.x specification as confirmed ground truth
for all standard endpoints, mandatory headers, body shapes, signing algorithm, and error codes.
Flag all Salt Edge / Artea sandbox-specific values as **"verify in portal"** rather than
speculating, and record them as hypotheses in `knowledge/salt_edge_ais/hypotheses.md`.

## Rationale

- The Berlin Group spec is public and stable; deviating from it in documentation would create
  misleading artefacts.
- Sandbox-specific overrides (base URL version, auto-SCA, callback param set) are low-risk to
  leave unconfirmed at this stage — they will be resolved during M3 TPP registration when live
  portal access is required anyway.
- Marking unknowns explicitly (⚠️) keeps documentation honest and gives a clear checklist for the
  portal verification session.

## Consequences

- `docs/tpp_discovery_notes.md` and `docs/ais_api_checklist.md` are actionable for M2 and M3 prep
  but carry explicit "verify in portal" flags on sandbox-specific items.
- Before starting M4 (Rails implementation), all open hypotheses in
  `knowledge/salt_edge_ais/hypotheses.md` must be resolved and their answers back-propagated into
  the discovery notes, checklist, and knowledge files.
- Any discrepancy found during portal verification must be recorded in
  `docs/inconsistencies_and_errors.md`.

# Integrations

## Salt Edge Scope (Current)
- Target integration is AIS flow simulation for Salt Edge Compliance sandbox.
- The detailed execution plan is in `docs/salt_edge_compliance_plan.md`.

## Primary Integration Artifacts
- Discovery: `docs/tpp_discovery_notes.md`
- API checklist: `docs/ais_api_checklist.md`
- Registration: `docs/tpp_registration_log.md`
- Flow trace: `docs/ais_flow_sequence.md`
- Evidence: `docs/ais_flow_evidence.md`
- Inconsistencies/errors: `docs/inconsistencies_and_errors.md`

## Certificate and Callback Inputs
- Certificate guide source: `docs/certificate_generation_guide.md`
- Certificate runbook: `docs/qseal_generation_runbook.md`
- Current generated public key for registration (local-only): `~/secrets/saltedge/qseal/guide_2026-04-04/client_public.key`
- Current connector URL used during portal registration: `https://ad18-109-185-141-9.ngrok-free.app` (ephemeral ngrok URL)
- Env contract uses `SE_*` variables from `.env.example` and `README.md`.

## Boundaries for Current Tasks
- Keep external-request logic isolated from controllers (service-style classes when implementation starts).
- Document any sandbox behavior mismatch in `docs/inconsistencies_and_errors.md` with reproducible context.

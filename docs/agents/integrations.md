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
- Certificate guide source: `docs/Certificate Generation Guide.pdf`
- Certificate runbook: `docs/qseal_generation_runbook.md`
- Env contract uses `SE_*` variables from `.env.example` and `README.md`.

## Boundaries for Current Tasks
- Keep external-request logic isolated from controllers (service-style classes when implementation starts).
- Document any sandbox behavior mismatch in `docs/inconsistencies_and_errors.md` with reproducible context.

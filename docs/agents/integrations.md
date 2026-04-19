# Integrations

## Salt Edge Scope (Current)
- Target integration is AIS flow simulation for Salt Edge Compliance sandbox.
- The detailed execution plan is in [salt_edge_compliance_plan.md](../salt_edge_compliance_plan.md).

## Primary Integration Artifacts
- Discovery: [tpp_discovery_notes.md](../tpp_discovery_notes.md)
- API checklist: [ais_api_checklist.md](../ais_api_checklist.md)
- Registration: [tpp_registration_log.md](../tpp_registration_log.md)
- Flow trace: [ais_flow_sequence.md](../ais_flow_sequence.md)
- Evidence: [ais_flow_evidence.md](../ais_flow_evidence.md)
- Inconsistencies/errors: [inconsistencies_and_errors.md](../inconsistencies_and_errors.md)

## Certificate and Callback Inputs
- Certificate guide source: [certificate_generation_guide.md](../certificate_generation_guide.md)
- Certificate runbook: [qseal_generation_runbook.md](../qseal_generation_runbook.md)
- QSeal cert/key are stored in the `certificates` table (private key encrypted via ActiveRecord::Encryption).
  The Rails app (`SaltEdge::SignatureBuilder`) reads from the DB — not from file-path env vars.
- Shell scripts (`script/`) still read from local files via `SE_QSEAL_CERT_PATH` / `SE_QSEAL_KEY_PATH`.
- Current connector URL used during portal registration: `https://ad18-109-185-141-9.ngrok-free.app` (ephemeral ngrok URL)
- Env contract: see `docs/milestone_4_ais_implementation_plan.md` → Environment Variable Contract section.

## Boundaries for Current Tasks
- Keep external-request logic isolated from controllers (service-style classes when implementation starts).
 - Document any sandbox behavior mismatch in [inconsistencies_and_errors.md](../inconsistencies_and_errors.md) with reproducible context.

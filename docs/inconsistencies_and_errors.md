# Inconsistencies and Errors

## Scope
Track mismatches between Salt Edge documentation and actual TPP sandbox behavior.

## Findings Log
| ID | Area | Doc Reference | Observed Behavior | Expected Behavior | Severity | Workaround | Status |
|---|---|---|---|---|---|---|---|
| 1 | TPP Verifier onboarding prerequisites | `docs/salt_edge_compliance_plan.md`, `https://priora.saltedge.com/docs/tpp_verifier#certificates-verify` | Verifier API requires valid `App-Id` / `App-Secret`, but obtaining these requires prior registration at `https://priora.saltedge.com/`; this prerequisite was not explicit in initial task docs. | Initial plan/docs should explicitly state Priora registration and credential retrieval before certificate verification can succeed. | High | Register first in Priora portal, obtain verifier client credentials from connection details, then rerun verification request. | Open |
| 2 | Priora availability during registration | `https://priora.saltedge.com/` | Priora portal stopped responding for more than 15 minutes while updating app registration with connector URL and public key. | Registration portal should remain available for completing app updates and credential retrieval. | High | Retry later and continue once portal is back; keep Milestone 0 marked incomplete until app registration update succeeds. | Open |

## Notes
- Add one row per issue with reproducible steps.
- Include request IDs or timestamps where possible.

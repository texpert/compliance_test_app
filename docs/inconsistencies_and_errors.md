
# Inconsistencies and Errors

## Scope
Track mismatches between Salt Edge documentation and actual TPP sandbox behavior.

## Findings Log
| ID | Area | Doc Reference | Observed (see details) | Expected Behavior | Severity | Workaround | Status |
|----|---|---|---|---|---|---|---|
| 1  | Priora availability during registration | `https://priora.saltedge.com/` | Priora portal downtime observed ([details][^obs2]) | Registration portal should remain available for completing app updates and credential retrieval. | High | Retry later and continue once portal is back; keep Milestone 0 marked incomplete until app registration update succeeds. | Open |
| 2  | `tpp/register` async certificate validation — opaque rejection for valid country, specific message for invalid country | `https://priora.saltedge.com/docs/berlingroup/artea_sandbox/certificates#tpp-register` | Opaque async rejections vs UK-specific message ([details][^obs3]) | Priora async review must return a specific failure reason for all rejection types, not only for country-not-found cases. | High | None available without Salt Edge support response. The UK vs Moldova error difference is the key escalation evidence: same infrastructure, different verbosity. | Open — awaiting support response |
| 3  | Base URL version mismatch — Berlin Group API | [tpp_discovery_notes.md](tpp_discovery_notes.md), [ais_api_checklist.md](ais_api_checklist.md) | Version intent clarified: Berlin Group SCA/AIS APIs use `v1`; OAuth/Priora APIs use `v2` ([details][^obs4]) | Documentation should clearly separate Berlin Group SCA/AIS endpoint versioning from Priora OAuth/session API versioning. | Medium | Apply explicit split in docs and keep service code scoped to `v1` for AIS/SCA calls. | Resolved — documented on 2026-04-10 |
| 4  | `POST /consents` response does not include `scaRedirect` link | `https://priora.saltedge.com/docs/berlingroup/artea_sandbox/ais#consents-create`, Berlin Group XS2A spec §7.3 | No `scaRedirect` link in response ([details][^obs7]) | Berlin Group spec states that a successful `POST /consents` with `TPP-Redirect-Preferred: true` MUST return `_links.scaRedirect.href` pointing to the ASPSP SCA page. | High | Obtain the SCA redirect URL manually from the Salt Edge UI: open the consent's authorisation record in the portal and copy the `redirect_url` field. Open it in a browser with the Artea sandbox PSU credentials. | Open — Artea sandbox limitation |

## Findings details (full descriptions)

[\^obs1]: Priora portal stopped responding for more than 15 minutes while updating app registration with connector URL and public key.

[\^obs2]: `tpp/register` repeatedly returns HTTP `200` but async email rejects with `given certificate is invalid` for Moldova (`C=MD`) certs — no field-level detail provided across 13 attempts spanning multiple cert profiles (sha1/sha256, CA:TRUE/FALSE, qcStatements variants, ST variants, real PSD2 orgId, near-original BG profiles). **However**, UK attempts (`C=UK`) returned a specific `country UK was not found` error, proving Priora CAN produce field-level rejection messages. This means: (a) `C=MD` passes country validation, (b) something else in the cert profile is rejected, and (c) Priora is not surfacing the specific reason for the Moldova failure despite being capable of doing so. Support emails sent 2026-04-05 and 2026-04-07.

[\^obs3]: Previous docs mixed `berlingroup/v2` base URL text with Berlin Group endpoint paths under `/v1/` (for example `POST /v1/consents`). This is now resolved: for this integration, SCA/AIS Berlin Group calls use `.../berlingroup/v1/...`; `v2` references are for OAuth/Priora session-token APIs and should not be used as the Berlin Group SCA/AIS base path.

[\^obs4]: On 2026-04-20, a successful `POST /artea_sandbox/api/berlingroup/v1/consents` (HTTP 201) returned `consentStatus: accepted` with `_links` containing only `status` and `scaStatus` (authorisations URL), but **no `scaRedirect`**. A follow-up `GET` to the consent details endpoint also returned no `scaRedirect`. A `GET` to the `scaStatus` authorisations URL returned a `redirect_url`, but that URL itself returned a 404. The only working path to the SCA redirect URL is through the Salt Edge portal UI, where the authorisation record for the consent shows the connector redirect URL. Response example: `{"consentId":"396244","consentStatus":"accepted","_links":{"status":{"href":"…/status"},"scaStatus":{"href":"…/authorisations/586492"}}}`.

## Notes
- Add one row per issue with reproducible steps.
- Include request IDs or timestamps where possible.

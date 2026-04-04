# TPP Registration Log

## Registration Metadata
- Environment: Local sandbox-preparation (Milestone 2)
- Registration date: Pending (Milestone 3)
- Registered TPP name: Pending
- `client_id`/identifier: Pending
- Public key prepared for portal registration: `$HOME/secrets/saltedge/qseal/guide_2026-04-04/client_public.key`
- Certificate fingerprint: `8F:9E:86:5B:B8:C8:80:A6:58:45:D4:1D:27:F2:0B:C3:40:63:6E:E5:A0:05:C6:9C:BE:4C:85:72:7D:59:A4:88`
- Certificate subject/issuer and serial number:
  - Subject: `CN=Fake TPP, O=Fake TPP, C=UK, ST=Fake Street, organizationIdentifier=PGB-123`
  - Issuer: `CN=Fake CA Authority, O=Fake CA, C=UK, ST=Fake street`
  - Serial: `207979942157E9641A45277249AB96EDA397B5C3`
- Certificate validity period:
  - `notBefore`: `Apr 4 15:08:53 2026 GMT`
  - `notAfter`: `Mar 30 15:08:53 2027 GMT`
- Certificate subject and policy OIDs:
  - Subject includes `organizationIdentifier` (`2.5.4.97` attribute type).
  - Extensions include `qcStatements` (as configured in local guide flow).
  - Full capture process and expected fields are defined in `docs/qseal_generation_runbook.md`.
- OpenSSL version used: `OpenSSL 3.6.1 27 Jan 2026 (Library: OpenSSL 3.6.1 27 Jan 2026)`
- Local chain readiness note: Self-signed CA chain artifact generated locally (`ca_certificate.crt`) and client cert signed (`client_signed_certifcate.crt`).

## Redirect Configuration
- Public callback base URL: `https://ad18-109-185-141-9.ngrok-free.app`
- Callback route: `/callback`
- Notes: Connector URL above was submitted during Priora registration flow (ephemeral ngrok tunnel, update if restarted).

## Result
- Registration status: Blocked (Priora portal update pending)
- Token or authorization entrypoint reachable: Pending
- TPP Verifier endpoint probe: Executed `POST https://priora.saltedge.com/api/tpp_verifiers/v2/certificates` with PEM certificate payload
- TPP Verifier response status: `404`
- TPP Verifier response error: `TppVerifierClientNotFound`
- Failure classification: **credential-scope** (verifier client credentials not recognized), not certificate-content scope
- Redacted credential-source evidence (Artea sandbox docs, retrieved 2026-04-04):
  - `Username`: `aR***AW`
  - `Password`: `ZN***<b`
  - `OTP`: `1***`
  - Source section: `Test credentials (Oauth)` at `https://priora.saltedge.com/docs/berlingroup/artea_sandbox`
- Current blocker: Priora portal became unavailable (>15 minutes) while updating app with connector URL and public key; retry required before Milestone 0 can be marked complete.

## Issues and Resolutions
| Timestamp | Step | Error | Resolution | Link/Reference |
|---|---|---|---|---|
| 2026-04-04 | Guide execution (`oid_section`) | OpenSSL OID registration conflict (`organizationIdentifier` already exists) | Removed explicit `oid_section` alias lines in local configs; used built-in OID mapping | Local run notes |
| 2026-04-04 | Client cert signing | Malformed local extension line from interrupted terminal input (`keyUsage` parse error) | Rewrote local `client_openssl.cnf` and re-ran signing successfully | Local run notes |
| 2026-04-04 | Salt Edge TPP Verifier API check (sample docs headers) | `404` / `TppVerifierClientNotFound` | Confirmed endpoint and PEM payload format are correct; sample docs `App-Id` is not valid in this environment | https://priora.saltedge.com/docs/tpp_verifier#certificates-verify |
| 2026-04-04 | Salt Edge TPP Verifier API check (Option B: Artea OAuth creds) | `404` / `TppVerifierClientNotFound` | Confirmed Artea OAuth test credentials are not TPP Verifier `App-Id`/`App-Secret`; need verifier client credentials from portal connection details | https://priora.saltedge.com/docs/berlingroup/artea_sandbox |
| 2026-04-04 | Priora app registration update | Priora portal unavailable for >15 minutes | Retry portal update when service recovers; keep Milestone 0 and Milestone 2 verification status pending | https://priora.saltedge.com/ |

## Secret Handling Confirmation
- Private keys, CSR bodies, passphrases, and PKCS#12 contents are intentionally not recorded in this file.

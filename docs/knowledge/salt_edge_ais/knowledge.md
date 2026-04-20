# Salt Edge AIS (Account Information Services) Knowledge

## Facts and Patterns

### API Standard
- Salt Edge Berlin Group implements the Berlin Group **NextGenPSD2 XS2A (Access to Account) Framework 1.3.x**.
- Base URL: `https://priora.saltedge.com`
- All AIS endpoints are prefixed with `/:provider_code/api/berlingroup/v1/`, where `provider_code` is the Salt Edge ASPSP identifier (e.g. `artea_sandbox`), **not** the TPP's internal provider code.
- Confirmed live against Artea sandbox on 2026-04-20.

### AIS Endpoints (confirmed against Artea sandbox, 2026-04-20)
All endpoints use the `/:provider_code/api/berlingroup/v1/` prefix.

- `POST /:provider_code/api/berlingroup/v1/consents` — create AIS consent
- `GET /:provider_code/api/berlingroup/v1/consents/{consentId}` — get consent details
- `GET /:provider_code/api/berlingroup/v1/consents/{consentId}/status` — get consent status
- `DELETE /:provider_code/api/berlingroup/v1/consents/{consentId}` — revoke consent
- `GET /:provider_code/api/berlingroup/v1/accounts` — account list; requires `Consent-ID` header
- `GET /:provider_code/api/berlingroup/v1/accounts/{account-id}/balances` — balances for one account
- `GET /:provider_code/api/berlingroup/v1/accounts/{account-id}/transactions` — transaction list; supports `dateFrom`, `dateTo`, `bookingStatus` query params
- `GET /:provider_code/api/berlingroup/v1/accounts/{account-id}/transactions/{transactionId}` — single transaction

### Consent Body Shape
```json
{
  "access": { "allPsd2": "allAccounts" },
  "recurringIndicator": true,
  "validUntil": "YYYY-MM-DD",
  "frequencyPerDay": 4,
  "combinedServiceIndicator": false
}
```
`validUntil` should be set to `Date.current + 180` (six months). `frequencyPerDay: 4` confirmed accepted.

### Consent Status Values
| Value | Meaning |
|---|---|
| `pending` | Local record created; upstream call not yet made (app-internal status) |
| `received` | Consent registered at ASPSP, awaiting SCA |
| `accepted` | Returned by Artea sandbox on successful POST (semantically equivalent to `received`) |
| `partiallyAuthorised` | SCA started but not completed (multi-step) |
| `valid` | SCA completed; consent usable for data access |
| `rejected` | SCA rejected by PSU or expired |
| `revokedByPsu` | PSU revoked the consent |
| `expired` | Consent validity period elapsed |
| `terminatedByTpp` | TPP revoked the consent |

### Mandatory Headers (all TPP-initiated calls)
| Header | Description |
|---|---|
| `X-Request-ID` | UUID v4, unique per request |
| `Date` | RFC 1123 format |
| `Digest` | `SHA-256=<base64(sha256(body))>`; empty-body value: `SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` |
| `Signature` | See format below |
| `TPP-Signature-Certificate` | Base64 of DER-encoded QSeal cert (no PEM delimiters) |

### Signing Algorithm (confirmed against Artea sandbox, 2026-04-20)
- Method: HTTP Signature (rsa-sha256)
- **`keyId` format**: `SN={certificate serial number},DN={issuer DN}` — not a hex fingerprint
- Signed headers (GET): `digest date x-request-id`
- Signed headers (POST /consents): `digest date x-request-id tpp-redirect-uri`
- Headers that **must not** be included in the signature: `Content-Type`, `PSU-IP-Address`, `TPP-Redirect-Preferred`
- Signature header value: `Signature keyId="SN=…,DN=…",algorithm="rsa-sha256",headers="digest date x-request-id [tpp-redirect-uri]",signature="<base64>"`

Salt Edge error when wrong headers are signed:
- `"All the following headers should be signed for your request: [\"Digest\", \"Date\", \"X-Request-ID\", \"TPP-Redirect-URI\"]"` — too few headers signed
- `"Only the following headers should be signed for your request: [\"Digest\", \"Date\", \"X-Request-ID\", \"TPP-Redirect-URI\"]"` — too many headers signed (e.g. Content-Type included)

### Certificate (QSeal) Requirements
- OID for PSD2 QCStatement: `0.4.0.19495.2`
- Role PSP_AI OID: `0.4.0.19495.1.1`
- Subject `organizationIdentifier`: `PSxx-{registrar}-{id}` format
- Key: RSA 2048+ or EC P-256/P-384
- Self-signed / locally-generated certs accepted by Artea sandbox (confirmed 2026-04-20)

### OpenSSL OID Behavior
- OpenSSL `1.1.1d+` and all `3.x` builds already include `organizationIdentifier` (`2.5.4.97`) as a built-in attribute name.
- In these versions, manual OID registration for `2.5.4.97` causes `OBJ_create: oid exists` and can break CSR/certificate generation.

### TPP-Redirect-URI Format
- Must be a path-based URL: `{callback_base_url}/callback/{local_consent_id}`
- The local `Consent` record must be created **before** calling upstream so its `id` is available to embed in the redirect URI.
- `consent_id` is CGI-escaped in the path (though it is always a numeric integer in practice).

### Artea Sandbox SCA Behavior
- SCA is **not** auto-approved. Real PSU credentials are required.
- Credentials are available at the Artea sandbox page in the Salt Edge portal.
- After the POST /consents call, the response does **not** include a `scaRedirect` link (see inconsistencies). The SCA redirect URL must be obtained manually from the Salt Edge UI (authorisations section for the consent).

### Generic TPP SCA Workflow (Redirect Model — Artea Sandbox)

#### Actors and Roles
- `PSU` (Payment Service User): end user authenticating and granting consent.
- `TPP`: app that initiates consent and consumes AIS APIs.
- `ASPSP` (Account Servicing Payment Service Provider): bank that performs SCA.

#### Core Workflow Steps
1. **Consent record creation**: Create local `Consent` record (status `pending`) first, so `consent.id` is available for the redirect URI.
2. **Upstream consent creation**: TPP calls `POST /:provider_code/api/berlingroup/v1/consents` with `TPP-Redirect-URI: {base}/callback/{consent.id}`. Response includes `consentId` and `consentStatus` (`accepted` in Artea sandbox). **No `scaRedirect` link is returned.**
3. **Persist upstream IDs**: Update the local `Consent` record with `upstream_consent_id` and mapped status.
4. **SCA redirect (manual)**: Obtain the SCA redirect URL from the Salt Edge portal UI (authorisations section). Open it in a browser with the Artea sandbox PSU credentials.
5. **Callback**: ASPSP redirects PSU to `{base}/callback/{consent.id}`. No `code` or `state` query parameters are returned by Artea sandbox.
6. **Post-callback validation**: App calls `GET /:provider_code/api/berlingroup/v1/consents/{consentId}/status`. Confirm status is `valid` before data access.
7. **Data access**: Call account/transaction endpoints with `Consent-ID: {consentId}`.

#### Token Exchange
- Artea sandbox does not return a `code` in the callback URL. Consent validity is established by status check only.

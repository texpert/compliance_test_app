# Salt Edge AIS (Account Information Services) Knowledge

## Facts and Patterns

### API Standard
- Salt Edge Berlin Group implements the Berlin Group **NextGenPSD2 XS2A (Access to Account) Framework 1.3.x**.
- Base URL pattern: `{host}/v1/` (version prefix; exact host to be confirmed from portal).

### AIS Endpoints (confirmed from Berlin Group spec)
- `POST /v1/consents` — create AIS consent; returns `consentId` + `_links.scaRedirect.href`
- `GET /v1/consents/{consentId}` — get consent details
- `GET /v1/consents/{consentId}/status` — get consent status (`received` → `valid` after SCA (Strong Customer Authentication))
- `DELETE /v1/consents/{consentId}` — revoke consent
- `GET /v1/accounts` — account list; requires `Consent-ID` header
- `GET /v1/accounts/{account-id}/balances` — balances for one account
- `GET /v1/accounts/{account-id}/transactions` — transaction list; supports `dateFrom`, `dateTo`, `bookingStatus` query params
- `GET /v1/accounts/{account-id}/transactions/{transactionId}` — single transaction

### Consent Body Shape
```json
{
  "access": { "allPsd2": "allAccounts" },
  "recurringIndicator": true,
  "validUntil": "2099-12-31",
  "frequencyPerDay": 4,
  "combinedServiceIndicator": false
}
```

### Mandatory Headers (all TPP (Third-Party Provider)-initiated calls)
| Header | Description |
|---|---|
| `X-Request-ID` | UUID (Universally Unique Identifier) v4, unique per request |
| `Date` | RFC1123 (Request for Comments 1123 date) |
| `Digest` | `SHA-256=<base64(sha256(body))>`; empty-body value: `SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` |
| `Signature` | `keyId="…",algorithm="rsa-sha256",headers="(request-target) date x-request-id digest",signature="…"` |
| `TPP-Signature-Certificate` | Base64 of DER-encoded QSEAL (Qualified Electronic Seal) cert (no PEM (Privacy-Enhanced Mail) delimiters) |

### Signing Algorithm
- Method: HTTP Signature (draft-cavage-http-signatures-12)
- Algorithm: `rsa-sha256`
- Signed headers: `(request-target) date x-request-id digest`
- `keyId`: SHA-256 fingerprint of QSEAL certificate, hex lowercase

### Certificate (QSEAL) Requirements
- OID (Object Identifier) for PSD2 (Payment Services Directive 2) QCStatement: `0.4.0.19495.2`
- Role PSP_AI (Payment Service Provider - Account Information) OID: `0.4.0.19495.1.1`
- Subject `organizationIdentifier`: `PSxx-{registrar}-{id}` format
- Key: RSA 2048+ or EC P-256/P-384

### OpenSSL OID Behavior
- OpenSSL `1.1.1d+` and all `3.x` builds already include `organizationIdentifier` (`2.5.4.97`) as a built-in attribute name.
- In these versions, manual OID registration for `2.5.4.97` causes `OBJ_create: oid exists` and can break CSR/certificate generation.
- Certificate output uses `organizationIdentifier` (name) instead of raw OID number `2.5.4.97`.

### Generic TPP SCA Workflow (Consent Redirect Model)

#### Actors and Roles
- `PSU` (Payment Service User): end user authenticating and granting consent.
- `TPP`: app that initiates consent and consumes AIS APIs.
- `ASPSP` (Account Servicing Payment Service Provider): bank that performs SCA and issues consent state updates.

#### Core Workflow Steps
1. **Initiation**: PSU starts an AIS journey in the TPP app.
2. **Consent creation**: TPP calls `POST /v1/consents` and receives `consentId`, `consentStatus`, and `_links.scaRedirect.href`.
3. **Redirection**: TPP redirects PSU to ASPSP SCA page via `scaRedirect`.
4. **Authentication and authorization**: PSU completes SCA at ASPSP (two independent factors) and approves requested access scope.
5. **Callback**: ASPSP redirects to `TPP-Redirect-URI` with `state` (and sometimes `code` depending on ASPSP model).
6. **Post-callback validation**: TPP verifies `state` (including replay protection), then checks `GET /v1/consents/{consentId}/status` until consent is usable (typically `valid`).
7. **Data access**: TPP calls account/transaction endpoints with `Consent-ID: {consentId}`.

#### Common Authentication Models
- **Redirect**: PSU authenticates on ASPSP web/app UI (most common for this project).
- **Decoupled**: PSU approves on separate channel/device while TPP waits for status update.
- **Embedded**: TPP collects auth input and submits to ASPSP APIs; less common and tighter security constraints.

#### Compliance Notes
- **Two-factor requirement**: SCA combines at least two independent factors (knowledge, possession, inherence).
- **Dynamic linking (payments)**: auth code must be tied to payment amount/payee (PIS-focused; noted for completeness).
- **Re-auth windows**: AIS consent re-auth cadence is ASPSP/regulatory-policy dependent (commonly 90-180 days).
- **Exemptions**: low-risk or recurring scenarios may qualify for SCA exemptions depending on ASPSP policy.

#### Token Exchange Caveat
- Some ASPSPs include an auth `code` during callback and require token exchange.
- In Berlin Group AIS consent flows used here, consent usability is primarily established by consent status checks, so `code` handling is optional and ASPSP-specific.

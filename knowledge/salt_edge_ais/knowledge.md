# Salt Edge AIS Knowledge

## Facts and Patterns

### API Standard
- Salt Edge Berlingroup implements the Berlin Group **NextGenPSD2 XS2A Framework 1.3.x**.
- Base URL pattern: `{host}/v1/` (version prefix; exact host to be confirmed from portal).

### AIS Endpoints (confirmed from Berlin Group spec)
- `POST /v1/consents` — create AIS consent; returns `consentId` + `_links.scaRedirect.href`
- `GET /v1/consents/{consentId}` — get consent details
- `GET /v1/consents/{consentId}/status` — get consent status (`received` → `valid` after SCA)
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

### Mandatory Headers (all TPP-initiated calls)
| Header | Description |
|---|---|
| `X-Request-ID` | UUID v4, unique per request |
| `Date` | RFC1123 date |
| `Digest` | `SHA-256=<base64(sha256(body))>`; empty-body value: `SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` |
| `Signature` | `keyId="…",algorithm="rsa-sha256",headers="(request-target) date x-request-id digest",signature="…"` |
| `TPP-Signature-Certificate` | Base64 of DER-encoded QSEAL cert (no PEM delimiters) |

### Signing Algorithm
- Method: HTTP Signature (draft-cavage-http-signatures-12)
- Algorithm: `rsa-sha256`
- Signed headers: `(request-target) date x-request-id digest`
- `keyId`: SHA-256 fingerprint of QSEAL certificate, hex lowercase

### Certificate (QSEAL) Requirements
- OID for PSD2 QCStatement: `0.4.0.19495.2`
- Role PSP_AI OID: `0.4.0.19495.1.1`
- Subject `organizationIdentifier`: `PSxx-{registrar}-{id}` format
- Key: RSA 2048+ or EC P-256/P-384

### SCA Flow
1. TPP creates consent → gets `consentId` + `scaRedirect` URL
2. TPP redirects PSU browser to `scaRedirect`
3. PSU authenticates at ASPSP
4. ASPSP redirects to `TPP-Redirect-URI` with `state` param (and possibly `code`)
5. TPP validates `state`, checks consent status → `valid`
6. TPP uses `Consent-ID: {consentId}` on all subsequent account/transaction calls

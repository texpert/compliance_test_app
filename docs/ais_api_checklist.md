# AIS (Account Information Services) API Checklist

This checklist describes a TPP (Third-Party Provider) flow where a PSU (Payment Service User) is redirected to the ASPSP (Account Servicing Payment Service Provider) for SCA (Strong Customer Authentication).

> **Artea sandbox endpoint prefix**: all endpoints use `/:provider_code/api/berlingroup/v1/` (e.g. `/artea_sandbox/api/berlingroup/v1/consents`, `/artea_sandbox/api/berlingroup/v1/accounts`).

## Happy Path Endpoints

| Step | Endpoint | Method | Required Headers | Request Body | Expected Response | Status |
|---|---|---|---|---|---|---|
| 4.1 Create consent | `POST /artea_sandbox/api/berlingroup/v1/consents` | POST | `X-Request-ID`, `Date`, `Content-Type`, `Digest`, `Signature` (signs: digest, date, x-request-id, tpp-redirect-uri), `TPP-Signature-Certificate`, `TPP-Redirect-Preferred: true`, `TPP-Redirect-URI`, `PSU-IP-Address` | `{"access":{"allPsd2":"allAccounts"},"recurringIndicator":true,"validUntil":"YYYY-MM-DD","frequencyPerDay":4,"combinedServiceIndicator":false}` | HTTP 201 `{"consentId":"…","consentStatus":"accepted","_links":{"status":{"href":"…"},"scaStatus":{"href":"…/authorisations/…"}}}` — **no `scaRedirect` link** (see inconsistency #7) | ✅ confirmed 2026-04-20 |
| 4.2 Get SCA redirect | Salt Edge portal UI → consent's authorisation record → `redirect_url` | Manual browser action | n/a | n/a | URL like `https://connector.saltedge.com/artea_sandbox/oauth/aisp/authorize/…` | ⚠️ `scaRedirect` not returned in API response; must be retrieved from portal |
| 4.3 Redirect to SCA | URL from step 4.2 | Browser navigation | n/a — browser carries no TPP headers | n/a | Artea sandbox renders SCA page | ✅ confirmed 2026-04-20 |
| 4.4 PSU completes SCA | Artea sandbox SCA screen | n/a (PSU action in browser) | n/a | n/a | ASPSP redirects PSU to `TPP-Redirect-URI` (path-based, no query params) | ✅ PSU credentials required from portal; not auto-approved |
| 4.5 Callback handling | `GET /callback/{consent_id}` | Rails inbound | n/a (inbound from ASPSP) | n/a | App records callback, calls `GET /artea_sandbox/api/berlingroup/v1/consents/{consentId}/status`, confirms `consentStatus: valid` | ✅ confirmed 2026-04-20; no `code` or `state` params returned |
| 4.6 Accounts list | `GET /artea_sandbox/api/berlingroup/v1/accounts[?withBalance=true]` | GET | `X-Request-ID`, `Date`, `Digest`, `Signature`, `TPP-Signature-Certificate`, `Consent-ID` | none | HTTP 200 `{"accounts":[{"resourceId":"…","iban":"…","currency":"…","name":"…","balances":[…],"_links":{…}}]}` — `balances` array only present when `withBalance=true` | ✅ confirmed from spec |
| 4.7 Transactions list | `GET /artea_sandbox/api/berlingroup/v1/accounts/{account-id}/transactions?bookingStatus=both&dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD` | GET | `X-Request-ID`, `Date`, `Digest`, `Signature`, `TPP-Signature-Certificate`, `Consent-ID` | none | HTTP 200 `{"transactions":{"booked":[…],"pending":[…]}}` | ✅ confirmed from spec |

## Consent Status Check (used in step 4.5)

| Step | Endpoint | Method | Required Headers | Request Body | Expected Response | Status |
|---|---|---|---|---|---|---|
| Status check | `GET /artea_sandbox/api/berlingroup/v1/consents/{consentId}/status` | GET | `X-Request-ID`, `Date`, `Digest`, `Signature`, `TPP-Signature-Certificate` | none | HTTP 200 `{"consentStatus":"valid"}` | ✅ confirmed 2026-04-20 |

## Pre-fetch Status Check for Accepted Consents

When a consent has status `accepted` (ASPSP registered the consent but SCA has not completed), the app performs a live status check before fetching accounts:

1. `GET /artea_sandbox/api/berlingroup/v1/consents/{consentId}/status`
2. If the returned status differs from the locally stored value, the local `Consent` record is updated.
3. If the status has not reached `valid`, the fetch is aborted with an alert directing the operator to complete SCA first.

This check is **only** performed when the selected consent is `accepted`; `valid` consents proceed directly to the accounts fetch.

## Error Cases to Validate

- **Expired or invalid consent**: `GET /v1/accounts` with expired `Consent-ID` → HTTP 401 `CONSENT_EXPIRED` or HTTP 403 `CONSENT_INVALID`
- **Invalid certificate/signature**: any signed request with bad `Signature` or `TPP-Signature-Certificate` → HTTP 401 `CERTIFICATE_INVALID` / `SIGNATURE_INVALID`
- **Wrong headers signed**: Salt Edge returns a 400 listing the exact set it requires, e.g. `"All the following headers should be signed: [\"Digest\", \"Date\", \"X-Request-ID\", \"TPP-Redirect-URI\"]"` or `"Only the following headers should be signed…"`
- **Callback with no upstream consent id**: app returns `unprocessable_content` with `missing_upstream_consent_id`
- **Replay protection**: duplicate callback payload returns HTTP 409 `state_replay`
- **Missing mandatory header**: any request missing `X-Request-ID` or required signed headers → HTTP 400 `{"tppMessages":[{"category":"ERROR","code":"FORMAT_ERROR","text":"…"}]}`
- **Consent not yet authorised**: calling `GET /v1/accounts` when `consentStatus` is still `received`/`accepted` → HTTP 403 `CONSENT_INVALID`

## Signing Quick Reference (confirmed against Artea sandbox, 2026-04-20)

```
Digest: SHA-256=<base64(SHA-256(raw-request-body))>

# GET requests and POST requests without TPP-Redirect-URI:
Signature: keyId="SN=<cert-serial>,DN=<cert-issuer>",algorithm="rsa-sha256",headers="digest date x-request-id",signature="<base64>"

# POST /consents (TPP-Redirect-URI must be signed):
Signature: keyId="SN=<cert-serial>,DN=<cert-issuer>",algorithm="rsa-sha256",headers="digest date x-request-id tpp-redirect-uri",signature="<base64>"

TPP-Signature-Certificate: <base64(DER-encoded-certificate)>
```

**Notes**:
- `keyId` is `SN={serial number},DN={issuer DN}` — **not** a hex fingerprint.
- `Digest` over empty body: `SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=`
- Do **not** include `Content-Type`, `PSU-IP-Address`, or `TPP-Redirect-Preferred` in the signed headers list.
- The signing string is lowercase header names, e.g. `tpp-redirect-uri: https://…`

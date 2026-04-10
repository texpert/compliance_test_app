# AIS (Account Information Services) API Checklist

This checklist describes a TPP (Third-Party Provider) flow where a PSU (Payment Service User) is redirected to the ASPSP (Account Servicing Payment Service Provider) for SCA (Strong Customer Authentication).

## Happy Path Endpoints

| Step | Endpoint | Method | Required Headers | Request Body | Expected Response | Status |
|---|---|---|---|---|---|---|
| 4.1 Create consent | `POST /v1/consents` | POST | `X-Request-ID`, `Date`, `Content-Type`, `Digest`, `Signature`, `TPP-Signature-Certificate`, `TPP-Redirect-Preferred`, `TPP-Redirect-URI`, `PSU-IP-Address` | `{"access":{"allPsd2":"allAccounts"},"recurringIndicator":true,"validUntil":"2099-12-31","frequencyPerDay":4,"combinedServiceIndicator":false}` | HTTP 201 `{"consentId":"…","consentStatus":"received","_links":{"scaRedirect":{"href":"…"},"self":{"href":"…"},"status":{"href":"…"}}}` | ✅ use Berlin Group `v1` for SCA/AIS |
| 4.2 Redirect to SCA | `_links.scaRedirect.href` (from 4.1 response) | Browser redirect (no direct API call) | n/a — browser carries no TPP headers | n/a | ASPSP renders SCA page; PSU authenticates | ⚠️ verify SCA UX in sandbox |
| 4.3 PSU completes SCA | ASPSP sandbox SCA screen | n/a (PSU action in browser) | n/a | n/a (sandbox: auto-approve or test credentials) | ASPSP redirects PSU to `TPP-Redirect-URI?state={state}` | ⚠️ verify auto-approve vs credentials in portal |
| 4.4 Callback handling | `GET /callback?state={state}[&code=...]` | Rails inbound | n/a (inbound from ASPSP) | n/a | App validates `state` (+ replay protection), optionally records `code`, calls `GET /v1/consents/{consentId}/status`, confirms `consentStatus: valid` | ⚠️ verify exact callback query params per ASPSP |
| 4.5 Accounts list | `GET /v1/accounts` | GET | `X-Request-ID`, `Date`, `Signature`, `TPP-Signature-Certificate`, `Consent-ID` | none | HTTP 200 `{"accounts":[{"resourceId":"…","iban":"…","currency":"…","name":"…","_links":{…}}]}` | ✅ confirmed from spec |
| 4.5 Transactions list | `GET /v1/accounts/{account-id}/transactions?bookingStatus=both&dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD` | GET | `X-Request-ID`, `Date`, `Signature`, `TPP-Signature-Certificate`, `Consent-ID` | none | HTTP 200 `{"transactions":{"booked":[…],"pending":[…]}}` | ✅ confirmed from spec |

## Consent Status Check (used in step 4.4)

| Step | Endpoint | Method | Required Headers | Request Body | Expected Response | Status |
|---|---|---|---|---|---|---|
| Status check | `GET /v1/consents/{consentId}/status` | GET | `X-Request-ID`, `Date`, `Signature`, `TPP-Signature-Certificate` | none | HTTP 200 `{"consentStatus":"valid"}` | ✅ confirmed from spec |

## Error Cases to Validate

- **Expired or invalid consent**: `GET /v1/accounts` with expired `Consent-ID` → HTTP 401 `CONSENT_EXPIRED` or HTTP 403 `CONSENT_INVALID`
- **Invalid certificate/signature**: any signed request with bad `Signature` or `TPP-Signature-Certificate` → HTTP 401 `CERTIFICATE_INVALID` / `SIGNATURE_INVALID`
- **Callback `state` mismatch**: Rails callback controller rejects and returns error page (app-level, no API call)
- **Missing mandatory header**: any request missing `X-Request-ID` or required signed headers → HTTP 400 with Berlin Group error format `{"tppMessages":[{"category":"ERROR","code":"FORMAT_ERROR","text":"…"}]}`
- **Consent not yet authorised**: calling `GET /v1/accounts` when `consentStatus` is still `received` → HTTP 403 `CONSENT_INVALID`

## Signing Quick Reference

```
Digest: SHA-256=<base64(SHA-256(raw-request-body))>
Signature: keyId="<hex-cert-fingerprint>",algorithm="rsa-sha256",headers="(request-target) date x-request-id digest",signature="<base64>"
TPP-Signature-Certificate: <base64(DER-encoded-certificate)>
```

For GET requests with no body: `Digest: SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` (SHA-256 of empty string).

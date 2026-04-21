# TPP (Third-Party Provider) Discovery Notes

## Scope
- Sandbox/Bank profile: Salt Edge Berlin Group — Artea sandbox
- Date reviewed: 2026-04-04
- Reviewer: agent (Milestone 1 baseline pass)

## Sources Reviewed
- Intro: Berlin Group NextGenPSD2 XS2A (Access to Account) Framework 1.3.x specification + Salt Edge Berlin Group portal introduction section
- Certificates: [certificate_generation_guide.md](certificate_generation_guide.md) (Salt Edge); eIDAS (electronic IDentification, Authentication and trust Services) QSEAL (Qualified Electronic Seal) requirements from ETSI EN 319 412
- AIS (Account Information Services) consents: Berlin Group spec §7 — consent creation, status, deletion
- Accounts: Berlin Group spec §7.3 — account list, account details
- Transactions: Berlin Group spec §7.4 — transaction list with date filters

## TLS Cipher Suite Policy
> Source: Salt Edge Priora changelog (announced 23 Dec 2021, effective 3 Feb 2022)

The following CBC-mode cipher suites are **no longer supported** on PSD2 (Payment Services Directive 2) APIs since 3 Feb 2022:
- `TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384`
- `TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256`

**Supported suites** (all GCM/CHACHA20 based):
- `TLS_AES_256_GCM_SHA384` (TLS 1.3)
- `TLS_CHACHA20_POLY1305_SHA256` (TLS 1.3)
- `TLS_AES_128_GCM_SHA256` (TLS 1.3)
- `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384` (TLS 1.2)
- `TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256` (TLS 1.2)
- `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256` (TLS 1.2)

All TLS 1.2 suites are `ECDHE-RSA-*` — RSA keys are used for authentication only, not key exchange. Our RSA 2048-bit certificate (`sha256WithRSAEncryption`) is **fully compatible** with all listed suites. See [certificate_generation_guide.md](certificate_generation_guide.md) §9 for verified details.

## Authentication and Signing Requirements
- Base URL for Berlin Group SCA/AIS calls: `https://ob.saltedge.com/api/berlingroup/v1/`
- Required headers (all requests):
  - `X-Request-ID` — UUID (Universally Unique Identifier) v4, unique per request (mandatory)
  - `Date` — RFC1123 (Request for Comments 1123 date) format, e.g. `Wed, 04 Apr 2026 04:00:00 GMT`
  - `Content-Type: application/json` (POST/PUT)
  - `Accept: application/json`
- Required headers (signed/TPP-initiated requests):
  - `Digest` — `SHA-256=<base64(SHA-256(body))>`; use `SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` for empty body
  - `Signature` — HTTP Signature per draft-cavage-http-signatures-12; format: `keyId="<hex-sha256-fingerprint>",algorithm="rsa-sha256",headers="(request-target) date x-request-id digest",signature="<base64>"`
  - `TPP-Signature-Certificate` — Base64-encoded QSEAL certificate PEM (Privacy-Enhanced Mail format, without `-----BEGIN/END CERTIFICATE-----` delimiters)
  - `PSU-IP-Address` — IP address of the PSU (Payment Service User) device _(⚠️ verify if enforced in sandbox)_
  - `TPP-Redirect-Preferred` — `"true"` to signal redirect-based SCA (Strong Customer Authentication) preference (required on consent creation)
  - `TPP-Redirect-URI` — Full callback URL for successful SCA
- Required header (account/balance/transaction calls):
  - `Consent-ID` — `consentId` value returned from consent creation
- Signature method: `rsa-sha256` (RSA PKCS#1 v1.5 with SHA-256); EC alternative `ecdsa-sha256` also allowed by spec
- Signed headers: `(request-target) date x-request-id digest`; include `tpp-signature-certificate` when present
- `keyId`: SHA-256 fingerprint of the QSEAL certificate, hex-encoded (lowercase)
- Certificate expectations:
  - QSEAL (Qualified Electronic Seal) or QTSP (Qualified Trust Service Provider)-issued test certificate
  - Must contain PSD2 `QCStatement` extension OID (Object Identifier) `0.4.0.19495.2` with role `PSP_AI` (Payment Service Provider - Account Information) (`0.4.0.19495.1.1`)
  - Subject `organizationIdentifier` in format `PSDE-BaFin-123456` (country prefix + registrar + ID)
  - Self-signed sandbox certificates accepted _(⚠️ confirm in portal)_
  - Key type: RSA 2048+ or EC P-256/P-384

## Redirect and Callback Contract
- Redirect URL configured: `https://ad18-109-185-141-9.ngrok-free.app/callback` (connector URL + callback route)
- Current connector URL observed during registration setup (ephemeral): `https://ad18-109-185-141-9.ngrok-free.app`
- Callback path in app: `GET /callback` (to be implemented in Milestone 4)
- Required query/body params on callback return:
  - `state` — mandatory; must match value sent in `TPP-Redirect-URI` query string at consent creation _(⚠️ verify exact param name in portal)_
  - `code` — may be present for OAuth-style flows _(⚠️ verify in portal)_
- `state` handling notes: generate a cryptographically random `state` value per consent request; store in session (or DB for Milestone 4); reject callback if `state` does not match; invalidate after first use

## Open Questions
- SCA in sandbox: does Artea auto-approve SCA or require test PSU credentials? If credentials are needed, where are they documented?
- Post-SCA callback params: does Salt Edge return only `state`, or also `code`? Is the consent status change synchronous?
- Is `PSU-IP-Address` validated or just logged in sandbox?
- Does the Artea sandbox enforce certificate chain validation or accept self-signed?

## Decisions
- All Berlin Group NextGenPSD2 standard endpoints, headers, and signing algorithm are treated as confirmed ground truth for this baseline.
- Endpoint version split is resolved: use Berlin Group `v1` for SCA/AIS endpoints, and use `v2` only for OAuth/Priora session-token APIs.
- All Salt Edge / Artea sandbox-specific behaviours (base URL, SCA UX, exact callback params) are flagged "verify in portal" and will be resolved no later than Milestone 3 (TPP registration).
- `state` will be stored server-side (session initially, DB if needed for audit) to support stateless callback validation.

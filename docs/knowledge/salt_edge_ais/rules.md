# Salt Edge AIS Rules

## Confirmed Rules

- **Always include `X-Request-ID`**: every API request must carry a unique UUID v4; reusing a value may cause the ASPSP to reject or deduplicate the request.

- **Always compute `Digest` for all requests**: even for an empty body, `Digest: SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` must be present and included in the signature.

- **Use `SN=…,DN=…` format for `keyId`**: the Artea sandbox backend expects DN-style keyId (`SN={serial},DN={issuer}`), not a hex fingerprint. Using a fingerprint causes a `Malformed signature` 400 error.

- **Sign only the required headers per endpoint**:
  - All requests: `digest date x-request-id`
  - POST /consents (and any request with `TPP-Redirect-URI`): `digest date x-request-id tpp-redirect-uri`
  - Do **not** include `Content-Type`, `PSU-IP-Address`, `TPP-Redirect-Preferred`, or other headers in the signature. Artea sandbox returns an error listing the exact set it expects.

- **Use `/:provider_code/api/berlingroup/v1/` prefix for consent endpoints**: the ASPSP identifier (`artea_sandbox`) goes at the start of the path, not after `/api/berlingroup/v1/`. The unprefixed `/v1/` path is only for accounts/transactions.

- **Create the local `Consent` record before calling upstream**: the local record's `id` is embedded in `TPP-Redirect-URI` as `/callback/{id}`. Upstream must receive this URI in the POST /consents request, so the record must exist first.

- **Reuse a pending consent on retry**: if a POST /consents call fails, the local `Consent` record (status `pending`) remains usable for a retry. Detect this by checking whether the record's last event has an `error` in `response_body`. This avoids creating duplicate consent records with the same redirect URI.

- **Artea sandbox requires PSU credentials for SCA**: SCA is not auto-approved. Obtain test credentials from the Artea sandbox page in the Salt Edge portal before attempting the full flow.

- **Check consent status after SCA using the correct URL**: `GET /:provider_code/api/berlingroup/v1/consents/{consentId}/status`. Do not assume consent is `valid` after redirect; always confirm before calling accounts/transactions.

- **The SCA redirect URL must be obtained from the Salt Edge portal**: Artea sandbox does not return `_links.scaRedirect` in the POST /consents response. Open the consent's authorisation record in the portal to find the redirect URL.

- **Never commit certificate or key material**: private keys and certificate files live outside the git repository; only metadata (fingerprint, subject, validity) goes in docs.

- **Must not add alias blocks for `organizationIdentifier` OID in OpenSSL configs**: for OpenSSL `1.1.1d+` and `3.x`, `oid_section`/`[new_oids]` aliases for `2.5.4.97` are forbidden; use `organizationIdentifier = ...` directly in DN fields.

- **Validate `state` on every callback**: reject any callback where `state` does not match the value stored server-side; invalidate the stored value after first use. (Note: Artea sandbox does not return `state` in the callback — correlation is via consent `id` in the URL path.)

- **Sanitize secrets in logs**: filter `Signature`, `TPP-Signature-Certificate`, and any bearer tokens from Rails logs (use `config.filter_parameters`).

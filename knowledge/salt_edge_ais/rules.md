# Salt Edge AIS Rules

## Confirmed Rules

- **Always include `X-Request-ID`**: every API request must carry a unique UUID v4 in `X-Request-ID`; reusing a value may cause the ASPSP to reject or deduplicate the request.
- **Always compute `Digest` for POST/PUT bodies**: even for an empty body, `Digest: SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` must be present in the `Signature` headers string.
- **Never commit certificate or key material**: private keys and certificate files live outside the git repository; only metadata (fingerprint, subject, validity) goes in docs.
- **Validate `state` on every callback**: reject any callback where `state` does not match the value stored server-side; invalidate the stored value after first use.
- **Check consent status after SCA**: do not assume consent is `valid` after redirect back; always confirm with `GET /v1/consents/{consentId}/status` before calling accounts/transactions.
- **Sanitize secrets in logs**: filter `Signature`, `TPP-Signature-Certificate`, and any bearer tokens from Rails logs (use `config.filter_parameters`).

# Salt Edge AIS Hypotheses

## Hypotheses Needing More Evidence

- **Base URL version**: assumed `https://ob.saltedge.com/api/berlingroup/v1/` — needs verification against Salt Edge Berlingroup portal intro page.
- **SCA in sandbox**: assumed Artea sandbox auto-approves SCA (no real PSU credentials required); needs confirmation; if credentials are required, test account details must be retrieved from portal.
- **Callback params after SCA**: assumed ASPSP returns only `state` in redirect URL (Berlin Group decoupled); uncertain whether `code` is also returned (OAuth-style); needs verification.
- **PSU-IP-Address enforcement**: assumed to be accepted but not validated in sandbox (logging only); needs confirmation.
- **TPP-Redirect-Preferred**: confirmed present on `POST /v1/consents` per Artea sandbox docs; sent as `"true"` to signal redirect-based SCA. `TPP-Nok-Redirect-URI` is NOT a header on this endpoint — removed from implementation.
- **Self-signed QSEAL accepted**: assumed sandbox does not enforce certificate chain/QTSP validation; needs confirmation before Milestone 2 certificate generation work.
- **Consent `access` field**: assumed `{"allPsd2":"allAccounts"}` shorthand is supported; alternatively may need explicit `accounts`/`balances`/`transactions` arrays.

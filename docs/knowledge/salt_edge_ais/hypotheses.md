# Salt Edge AIS Hypotheses

## Hypotheses Needing More Evidence

- **PSU-IP-Address enforcement**: assumed to be accepted but not validated in sandbox (logging only); needs confirmation.

- **Consent `access` field**: assumed `{"allPsd2":"allAccounts"}` shorthand is supported; alternatively may need explicit `accounts`/`balances`/`transactions` arrays. (Used successfully so far, but not confirmed as the only accepted form.)

## Resolved Hypotheses

- **Base URL and endpoint prefix** ✅ CONFIRMED 2026-04-20:
  Base is `https://priora.saltedge.com`; consent endpoints use `/:provider_code/api/berlingroup/v1/` prefix (e.g. `/artea_sandbox/api/berlingroup/v1/consents`). The `/v1/` shorthand without the provider prefix results in 404.

- **SCA in sandbox** ✅ CONFIRMED 2026-04-20:
  Artea sandbox does **not** auto-approve SCA. Real PSU credentials are required; obtain them from the Artea sandbox credentials page in the Salt Edge portal.

- **Callback params after SCA** ✅ CONFIRMED 2026-04-20:
  Artea sandbox redirects to `{TPP-Redirect-URI}` with no `state` or `code` query parameters. The redirect URI uses a path segment for correlation (`/callback/{consent_id}`), so no query-param state matching is needed.

- **Self-signed QSEAL accepted** ✅ CONFIRMED 2026-04-20:
  Locally-generated, self-signed QSeal certificates (using a locally-generated CA) are accepted by the Artea sandbox for signing consent creation requests.

- **`TPP-Redirect-Preferred`** ✅ CONFIRMED:
  Sent as `"true"` string on POST /consents. Accepted without error.

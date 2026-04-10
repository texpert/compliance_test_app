# Priora API Changelog

Extracted from the internal Priora application page for this integration.

---

## ASPSP API Update — Salt Edge PSD2 / Berlin Group NextGenPSD2 XS2A 1.3.4

### Summary
Added support for Salt Edge PSD2 compliance solution compatible with **Berlin Group NextGenPSD2 XS2A API, version 1.3.4**.
Upgraded Connector & Salt Edge callback endpoints in accordance with RESTful API design.

---

### Salt Edge Endpoints (Connector → Priora)

| Old (v1) | New (v2) | Method change | Body change |
|---|---|---|---|
| `POST /api/connectors/v1/sessions/success` | `PATCH /api/connectors/v2/sessions/:session_secret/success` | POST → PATCH | `data.scopes` removed; `data.refresh_token` removed |
| `POST /api/connectors/v1/sessions/update` | `PATCH /api/connectors/v2/sessions/:session_secret/update` | POST → PATCH | `data.extra.redirect_url` extracted to `data.redirect_url`; `data.user_id` removed |
| `POST /api/connectors/v1/sessions/fail` | `PATCH /api/connectors/v2/sessions/:session_secret/fail` | POST → PATCH | — |
| `GET /api/connectors/v1/tokens/index` | `GET /api/connectors/v2/tokens` | — | — |

---

### Connector Endpoints (Priora → Connector / our app)

| Endpoint | Change |
|---|---|
| `GET /api/priora/v2/accounts` | Now requires a **NextGenPSD2 standard response** |
| `GET /api/priora/v2/accounts/:account_id/transactions` | Now requires a **NextGenPSD2 standard response** |
| `POST /api/priora/v1/tokens/refresh` | **Removed** (deprecated) |
| `POST /api/priora/v1/tokens/reconnect` | **Removed** |
| `POST /api/priora/v1/tokens/cancel` | **Removed** |
| `POST /api/priora/v1/tokens/revoke` | Renamed → `PATCH /api/priora/v2/tokens/revoke` |
| `POST /api/priora/v1/tokens/create` | Renamed → `POST /api/priora/v2/tokens` |

#### Request body changes (all connector POST endpoints)
- `data.original_request` field **removed** along with all nested content.
- `data.original_request.client_payload.data.credentials.authorization_type` promoted to **`data.authorization_type`**.

---

## Impact Assessment for This Integration

### AIS API Checklist ([ais_api_checklist.md](ais_api_checklist.md))
- The checklist uses Berlin Group XS2A endpoints (`/v1/consents`, `/v1/accounts`, etc.) — these are **ASPSP-facing Berlin Group standard endpoints**, not Priora internal endpoints. The `/v1/` in `POST /v1/consents` refers to the Berlin Group API version prefix, not the Priora connector version. These remain unchanged.
- ✅ Version split confirmed: use `berlingroup/v1` for Berlin Group SCA/AIS endpoints, and use Priora `v2` endpoints only for OAuth/session-token flows.

### Session/Token Flow
- If our app ever calls `sessions/success`, `sessions/fail`, or `sessions/update` back to Priora (e.g. for OAuth callback handling), it **must** use the `v2` PATCH endpoints and the updated body shape.
- Token revoke calls must use `PATCH /api/priora/v2/tokens/revoke` (not POST v1).
- `tokens/refresh`, `tokens/reconnect`, `tokens/cancel` are all gone — do not implement these.

### Accounts/Transactions Response Format
- `GET /api/priora/v2/accounts` and `GET /api/priora/v2/accounts/:account_id/transactions` both require **NextGenPSD2-standard response bodies**. Our service objects (`AccountsService`, `TransactionsService`) must return data in this format.

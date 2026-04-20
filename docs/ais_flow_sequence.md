# AIS (Account Information Services) Flow Sequence

## Objective
Document one reproducible happy-path run from consent creation to availability of endpoints to retrieve accounts and transactions. Includes SCA between the PSU and the Artea sandbox ASPSP.

## Run Metadata
- Date/time: 2026-04-20
- Environment: Artea sandbox (`artea_sandbox` provider code)
- App commit hash: cee0b0f (feature/admin-consent-flow)
- ngrok tunnel: `https://1330-109-185-141-9.ngrok-free.app`

## Step-by-Step Trace

### 4.1 Create Consent

**Trigger**: Admin clicks "Create Consent" on Provider show page.

**Pre-conditions**:
- Provider has an issued QSeal certificate (cert is loaded from DB, private key decrypted on read).
- `registration_request_sent_at` is set on the provider.
- No existing `pending` consent with a non-error last event (otherwise the existing record is reused).

**Request**:
```
POST https://priora.saltedge.com/artea_sandbox/api/berlingroup/v1/consents
```
Signed headers: `digest date x-request-id tpp-redirect-uri`
`TPP-Redirect-URI`: `https://{ngrok-tunnel}/callback/{local_consent_id}`

Body:
```json
{
  "access": { "allPsd2": "allAccounts" },
  "recurringIndicator": true,
  "validUntil": "2026-10-17",
  "frequencyPerDay": 4,
  "combinedServiceIndicator": false
}
```

**Response** (HTTP 201):
```json
{
  "consentId": "396244",
  "consentStatus": "accepted",
  "_links": {
    "status": { "href": "/artea_sandbox/api/berlingroup/v1/consents/396244/status" },
    "scaStatus": { "href": "/artea_sandbox/api/berlingroup/v1/consents/396244/authorisations/586492" }
  }
}
```

**Note**: `_links.scaRedirect` is **absent**. This is a known inconsistency with the Berlin Group spec (see inconsistency #7). The consent status is `accepted` (Artea sandbox equivalent of `received`).

**Persisted**: local `Consent` updated with `upstream_consent_id: "396244"`, `status: "accepted"`.

---

### 4.2 Get SCA Redirect URL

Since no `scaRedirect` is returned by the API, the SCA redirect URL must be obtained manually:

1. Open the Salt Edge portal UI.
2. Navigate to the Artea sandbox consent authorisation record (authorisation ID `586492`).
3. Copy the `redirect_url` field value, e.g.:
   ```
   https://connector.saltedge.com/artea_sandbox/oauth/aisp/authorize/138cdb38-c8eb-46f7-b83c-9c8ecc63749b
   ```

---

### 4.3 PSU Completes SCA

1. Open the redirect URL from step 4.2 in a browser.
2. The Artea sandbox displays a login/authorization page.
3. Enter PSU credentials from the Artea sandbox credentials page in the Salt Edge portal.
4. Approve the consent.

**Outcome**: ASPSP redirects the browser to `https://{ngrok-tunnel}/callback/{local_consent_id}` with no query parameters.

---

### 4.4 Callback Handling

**Inbound request**:
```
GET /callback/2
```
No `code` or `state` query parameters (Artea sandbox does not include them).

**App processing**:
1. Loads `Consent` record by `id` from path.
2. Checks replay protection (no prior event with same payload).
3. Updates `callback_received_at`.
4. Calls `GET /artea_sandbox/api/berlingroup/v1/consents/396257/status`.

**Consent status response**:
```json
{ "consentStatus": "valid" }
```

5. Updates `Consent.status` to `valid`.
6. Records a `consent_status_check` event.
7. Records a `callback` event.
8. Returns HTTP 302 redirect to the consent show page.

---

### 4.5 Fetch Accounts (admin action)

**Trigger**: Admin clicks "Fetch Accounts" on the Provider show page (button visible when at least one `valid` or `accepted` consent exists).

**Flow**:

1. Admin navigates to the Fetch Accounts form (`GET /admin/providers/:id/new_fetch_accounts`).
2. Form shows all eligible consents (status `valid` or `accepted`) with their status displayed, plus a **withBalance** checkbox.
3. Admin selects a consent and optionally checks `withBalance`, then submits.

**If the selected consent is `accepted`** (SCA not yet confirmed):

4. App calls `GET /artea_sandbox/api/berlingroup/v1/consents/{consentId}/status`.
5. Local `Consent` record updated if status has changed.
6. If status has not reached `valid`, flow is aborted and an alert is shown:
   > "Consent N status is 'accepted' — please authorise it first or choose a different consent."
7. If status is now `valid`, flow proceeds.

**Accounts fetch**:

8. App calls `GET /artea_sandbox/api/berlingroup/v1/accounts[?withBalance=true]` with `Consent-ID: {upstream_consent_id}`.
9. Each account is upserted by `resourceId` (no FK to consent or provider — accounts are global per PSU at the ASPSP).
10. If `withBalance=true`, each account's `balances` array is upserted by `(account_id, balance_type)`.
11. On success, admin is redirected to `/admin/accounts` sorted by `updated_at desc` with a success notice.

**Account balance fields** (when `withBalance=true`):

| Field in upstream | Local column | Notes |
|---|---|---|
| `balanceType` | `balance_type` | e.g. `closingBooked`, `interimAvailable` |
| `balanceAmount.amount` | `amount` | Decimal 15,2 |
| `balanceAmount.currency` | `currency` | Falls back to account currency if absent |
| `creditLimitIncluded` | `credit_limit_included` | Boolean, default false |
| `referenceDate` | `reference_date` | Date |
| `lastChangeDateTime` | `last_change_date_time` | Datetime |

**Transactions**: triggered separately from the Account show page; see step 4.6.

---

### 4.6 Fetch Transactions (admin action)

**Trigger**: Admin clicks "Fetch Transactions" on the Account show page (button visible when at least one `valid` or `accepted` consent exists globally).

**Flow**:

1. Admin navigates to the Fetch Transactions form (`GET /admin/accounts/:id/new_fetch_transactions`).
2. Form shows:
   - Consent selector (all `valid`/`accepted` consents across all providers, labelled with provider name)
   - **Date From** (default: 90 days ago)
   - **Date To** (default: today)
   - **Booking Status** selector: `both` (default), `booked only`, or `pending only`
   - **Paginated** checkbox (unchecked by default)
3. Admin selects a consent and adjusts options, then submits.

**If the selected consent is `accepted`**: same live status check as in step 4.5 (see above).

**Non-paginated fetch** (default):

4. App calls `GET /{provider_code}/api/berlingroup/v1/accounts/{resourceId}/transactions?bookingStatus={status}&dateFrom={from}&dateTo={to}` with `Consent-ID`.
5. Booked transactions upserted by `(account_id, transaction_id)`; pending transactions deleted and recreated.
6. Admin redirected to Account show page with a count notice.

**Paginated fetch** (`paginated` checked):

4. App calls the same URL with `&paginated=1` appended.
5. Response contains up to 50 transactions and may include `_links.next.href`.
6. App persists the current page's booked and pending transactions, then follows `_links.next.href` until it is absent.
7. Memory usage is bounded to one page at a time — each page is persisted before the next fetch.

**On success**: admin redirected to Account show page with "Fetched N transaction(s) successfully."

**Transactions panel** on Account show page displays the 20 most recent transactions with a link to the full filtered index (`/admin/transactions?q[account_id_eq]={id}`).

---

## Known Deviations from Berlin Group Spec

1. **No `scaRedirect` in POST /consents response** — Artea sandbox returns only `scaStatus` link. SCA redirect must be obtained from the portal UI. See inconsistency #7.
2. **No query parameters in callback** — Artea sandbox does not return `state` or `code`. Consent correlation is via the path segment (`/callback/{consent_id}`).
3. **`consentStatus: accepted`** — Artea sandbox uses `accepted` where the spec says `received` for a newly-created consent awaiting SCA. Both are treated as equivalent (mapped to `received` in the app's status enum fallback).

## Notes
- The test-suite intentionally seeds an Event with `event_type: 'replay_marker'` to simulate prior processing when exercising replay-detection logic. In the current implementation there is no production code that automatically creates `replay_marker` events — tests or an external process insert them. If you expect production to mark processed callbacks as replayable, add an idempotent write of a `replay_marker` after successful processing and cover it with specs.
- PSU credentials for the Artea sandbox are available on the sandbox credentials page in the Salt Edge portal. Do not commit them.

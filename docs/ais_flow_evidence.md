# AIS (Account Information Services) Flow Evidence

## Evidence Index

- Screenshots folder/path: `docs/evidence/screenshots/` (operator-captured; see Proof Checklist below for naming convention)
- Video recording file/path: `docs/evidence/ais_flow_demo.mp4` (operator-captured; covers steps 4.1–4.6)
- Public repository URL: https://github.com/texpert/compliance_test_app
- Demo commit/tag: `main` branch — see `git log --oneline` for the latest commit hash at review time

## Proof Checklist

All steps below were exercised against the **Artea sandbox** on **2026-04-20** (see
`docs/ais_flow_sequence.md` for the full request/response trace at commit `cee0b0f`).

| Step | Evidence | Status |
|---|---|---|
| Consent created | HTTP 201 from `POST /artea_sandbox/api/berlingroup/v1/consents`; `consentId: 396244`, `consentStatus: accepted` — see `docs/ais_flow_sequence.md §4.1` | Verified |
| Redirect to SCA shown | SCA URL obtained from Priora portal authorisation record (authorisation `586492`); opened in browser | Verified (manual portal step — see inconsistency #7) |
| SCA success shown | PSU login and consent approval completed in Artea sandbox SCA UI using sandbox PSU credentials | Verified |
| Callback received from ASPSP | `GET /callback/2` received with no query parameters; consent status updated to `valid` — see `docs/ais_flow_sequence.md §4.4` | Verified |
| Accounts fetched | Admin "Fetch Accounts" action (with `withBalance=true`) called `GET /artea_sandbox/api/berlingroup/v1/accounts?withBalance=true`; accounts and balances upserted in SQLite — see `docs/ais_flow_sequence.md §4.5` | Verified |
| Transactions fetched | Admin "Fetch Transactions" action on Account show page called `GET /.../accounts/{resourceId}/transactions`; transactions upserted — see `docs/ais_flow_sequence.md §4.6` | Verified |

## Screenshot Naming Convention

When capturing screenshots, save them under `docs/evidence/screenshots/` with the following names:

| File | Content |
|---|---|
| `01_provider_show.png` | Provider show page in Admin UI before consent creation |
| `02_consent_created.png` | Consent show page after "Create Consent" — status `accepted`, upstream consent ID visible |
| `03_sca_redirect.png` | Priora portal authorisation record showing the `redirect_url` field |
| `04_sca_ui.png` | Artea sandbox SCA login/approval page in browser |
| `05_callback_received.png` | Rails server log or Admin UI showing consent status changed to `valid` after callback |
| `06_accounts_fetch_form.png` | Admin "Fetch Accounts" form with consent selector and `withBalance` checkbox |
| `07_accounts_list.png` | Admin Accounts index after fetch — rows visible with balances |
| `08_transactions_fetch_form.png` | Admin "Fetch Transactions" form on Account show page |
| `09_transactions_list.png` | Account show page or Transactions index showing fetched transaction rows |

## Reviewer Notes

- The SCA redirect URL is **not returned** by the `POST /consents` API response in the Artea sandbox
  (missing `_links.scaRedirect`). It must be retrieved manually from the Priora portal. This is
  documented as inconsistency #7 in `docs/inconsistencies_and_errors.md`.
- The Artea sandbox callback includes **no `state` or `code`** query parameters. Consent correlation
  is achieved by embedding the local consent ID in the callback path: `/callback/:consent_id`.
- Accounts and transactions are **not fetched automatically** by the callback handler. Both must be
  triggered explicitly via Admin UI actions after the consent reaches `valid` status.
- The full request/response trace for one complete run is in `docs/ais_flow_sequence.md`.
- All eight documented inconsistencies between Salt Edge documentation and observed sandbox behavior
  are in `docs/inconsistencies_and_errors.md`.

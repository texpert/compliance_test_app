# AIS (Account Information Services) Flow Sequence

## Objective
Document one reproducible happy-path run from consent creation to availability of endpoints to retrieve accounts and transactions (fetching is performed via explicit/manual actions or scheduled jobs). Include SCA (Strong Customer Authentication) between the PSU (Payment Service User) and ASPSP (Account Servicing Payment Service Provider).

## Run Metadata
- Date/time:
- Environment:
- App commit hash:

## Step-by-Step Trace
### 4.1 Create Consent
- Request summary:
- Response summary:
- Consent ID:

### 4.2 Redirect to SCA
- Redirect URL:
- Parameters sent:

### 4.3 PSU Completes SCA at ASPSP
- Authentication factors used (sandbox):
- Authorization decision and outcome:

### 4.4 Redirect Back / Callback
- Callback URL hit:
- Parameters received:
- State verification result:
- Replay-protection result:
- Consent status check result (`GET /v1/consents/{consentId}/status`):

### 4.5 Accounts and Transactions (manual fetch)
- Accounts response summary:
- Transactions response summary:

## Notes
- 
- 
- Note: The test-suite intentionally seeds an Event with `event_type: 'replay_marker'` to simulate prior processing when exercising replay-detection logic. In the current implementation there is no production code that automatically creates `replay_marker` events — tests or an external process insert them. If you expect production to mark processed callbacks as replayable, add an idempotent write of a `replay_marker` after successful processing and cover it with specs.

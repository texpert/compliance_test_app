# AIS (Account Information Services) Flow Sequence

## Objective
Document one reproducible happy-path run from consent creation to transactions retrieval, including SCA (Strong Customer Authentication) between the PSU (Payment Service User) and ASPSP (Account Servicing Payment Service Provider).

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

### 4.5 Fetch Accounts and Transactions
- Accounts response summary:
- Transactions response summary:

## Notes
- 
- 

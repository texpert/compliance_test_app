# TPP Register Artifact Preservation and Comparison

## Preserved artifacts

### Successful request artifacts (from `/tmp`)
- `successful/tpp_register_retry_20260404.sh`
- `successful/tpp_register_retry_trace.txt`
- `successful/tpp_register_retry_response.json`

### Latest request artifacts (from `/tmp` + current repo script)
- `latest/tpp_register_payload.json`
- `latest/tpp_register_response.json`
- `latest/tpp_register_signing_string.txt`
- `latest/tpp_register_trace.txt` (historical trace file in `/tmp`, not the 2026-04-06 20:54 retest)
- `latest/tpp_register_retry.sh` (snapshot of `/tmp` script)
- `latest/tpp_register_retry_current.sh` (snapshot of the then-current repo script `script/tpp_register_retry.sh`; script later removed during housekeeping)

## Outcome comparison
- Successful request response: `HTTP 200` with `{"message":"Request is processed..."}` (`successful/tpp_register_retry_response.json`).
- Latest retest response: `HTTP 400` with `Header 'Signature' invalid: Malformed signature` (`latest/tpp_register_response.json`).

## What changed between successful and latest request shape

### 1) JSON payload shape
- **Successful request** (`successful/tpp_register_retry_trace.txt`): flat body with top-level `company`, `representative`, `certificate` and no `certificate.value` field; `Content-Length: 402`.
- **Latest request** (`latest/tpp_register_payload.json`): wrapped in `data`, includes `certificate.value` carrying base64 certificate bytes.

### 2) Signed headers and canonical string
- **Successful script** (`successful/tpp_register_retry_20260404.sh`):
  - `headers="digest date x-request-id"`
  - signing string lines: `digest`, `date`, `x-request-id`.
- **Latest script** (`latest/tpp_register_retry_current.sh`):
  - `headers="(request-target) date x-request-id digest"`
  - signing string includes `(request-target): post /api/berlingroup/v1/tpp/register` and reorders fields.
  - Evidence: `latest/tpp_register_signing_string.txt`.

### 3) `keyId` format
- **Successful**: DN-style key id:
  - `keyId="SN=0,DN=/organizationIdentifier=.../CN=.../O=.../C=.../ST=..."`
  - Evidence: `successful/tpp_register_retry_trace.txt` header block.
- **Latest**: SHA-256 certificate fingerprint (hex, lowercase, colonless) in `keyId`.
  - Evidence: `latest/tpp_register_retry_current.sh`.

### 4) `TPP-Signature-Certificate` encoding
- **Successful**: base64 of full PEM text (header starts with `LS0tLS1CRUdJTi...`, which decodes to `-----BEGIN CERTIFICATE-----`).
  - Evidence: `successful/tpp_register_retry_trace.txt`.
- **Latest**: certificate converted to DER then base64-encoded.
  - Evidence: `latest/tpp_register_retry_current.sh` (`openssl x509 -outform der` + `base64`).

### 5) Request defaults
- **Successful trace** uses curl default `Accept: */*`.
- **Latest script** explicitly sets `Accept: application/json`.
- This difference is low risk compared to signature canonicalization differences above.

## Important note about `latest/tpp_register_trace.txt`
- The copied `latest/tpp_register_trace.txt` contains a request with `Signature: Signature keyId="", ... signature=""` and `HTTP 400`.
- That trace appears to be from an older malformed request script in `/tmp` and does not match the verified 2026-04-06 20:54 retest signatures.
- The verified latest retest evidence is in:
  - `latest/tpp_register_signing_string.txt`
  - `latest/tpp_register_response.json`
  - current script snapshot `latest/tpp_register_retry_current.sh`

## Controlled replay (old successful shape)
- Added replay script: `script/tpp_register_replay_success_shape.sh`.
- It forces the historical request shape from the successful call:
  - flat payload (`company`, `representative`, `certificate`),
  - signed headers `digest date x-request-id`,
  - DN-style `keyId`,
  - `TPP-Signature-Certificate` as base64 of full PEM.
- Replay artifacts are stored in `replay_success_shape_2026-04-07/`:
  - `replay_success_shape_2026-04-07/tpp_register_replay_payload.json`
  - `replay_success_shape_2026-04-07/tpp_register_replay_signing_string.txt`
  - `replay_success_shape_2026-04-07/tpp_register_replay_trace.txt`
  - `replay_success_shape_2026-04-07/tpp_register_replay_response.json`

### Replay outcome
- Replay still fails with `HTTP 400` and `Header 'Digest' invalid. Expected format: SHA-256={SHA256Base64(requestBody)}`.
- Request correlation from replay trace:
  - `X-Request-ID: 6b6f3729-f928-46e0-878a-36e4924aaf2b`
  - `Date: Mon, 06 Apr 2026 21:30:54 GMT`
  - `Digest: SHA-256=tPebFMB03olmURhEYvaKuHC0c+C2bchhX+0zBanArCE=`

### Implication
- Even when reproducing the previously accepted request contract, the backend no longer follows the old acceptance path (`HTTP 200`).
- Current behavior remains consistent with a server-side validation-path change/regression rather than a single client formatting drift.

## Conclusion
The request format has materially changed since the successful call: payload contract, signed-header set/order, keyId format, and certificate-header encoding. Any one of these can alter backend signature parsing; together they represent a substantial protocol drift from the known-accepted request.

## Quick diff table
- Header-by-header and params matrix: `one_page_header_params_diff_2026-04-07.md`
- Wire-level trace comparison: `wire_trace_comparison_2026-04-07.md`

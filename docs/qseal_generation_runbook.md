# QSEAL Generation Runbook

## Goal
Generate sandbox-compatible certificate artifacts for Salt Edge TPP registration using the guide flow, with all secret material kept outside git.

## Canonical Source
- `docs/certificate_generation_guide.md`
- `docs/agents/secrets.md`

## Attempt Folder Rule (Strict)
- Use a **new folder for every certificate generation attempt**.
- Never overwrite a previous attempt folder.
- Folder naming pattern: `guide_YYYY-MM-DD-<attempt-tag>` (examples: `guide_2026-04-04`, `guide_2026-04-04-texpert`, `guide_2026-04-04-texpert-v2`).
- If a folder already exists, stop and create a new attempt tag instead of regenerating in place.
- Record each attempt folder path in `docs/tpp_registration_log.md` with outcome notes.

## Near-Original BG Script Sync Rule (Strict)
- For every new attempt using `script/originals/bg_cert_gen.sh`, pass the company name as a quoted argument:
  - `./bg_cert_gen.sh -n "<COMPANY_NAME>"`
- For every new attempt using `bg_register.rb`, you must update all three values before running:
  - `YOUR_PEM_CERTIFICATE` path -> current attempt certificate file
  - `YOUR_CERTIFICATES_PRIVATE_RSA_KEY` path -> current attempt private key file
  - `COMPANY_NAME` -> same company name used in the quoted `-n` argument
- Do not run `bg_register.rb` until these per-attempt values are updated.
- Canonical policy location during experimentation: this section + `docs/tpp_registration_log.md` (cross-link each new attempt row to this rule).

## Local Execution Record (Milestone 2)
- Execution date: `2026-04-04` (initial); last regeneration: `2026-04-07`
- Latest attempt path (outside repo): `./secrets/qseal/guide_2026-04-07-texpert-bank-bg-original-02`
- Latest attempt status: original `bg_cert_gen.sh` run failed on OpenSSL OID aliasing (`OBJ_create: oid exists`); CSR/certificate outputs were not produced in this folder.
- Latest successful full-chain path: `./secrets/qseal/guide_2026-04-07-bnm-test-bg-originalish-01`
- Name flag used: `BNM TEST` (display name preserved in DN fields; file slug kept as `bnm_test` for shell-safe local paths)
- Output files generated locally (latest attempt):
  - `ca_private.key` ✓
  - `ca.csr` ✓
  - `ca_certificate.crt` ✓
  - `ca_certificate.srl` ✓
  - `ca_openssl.cnf` ✓
  - `bnm_test/bnm_test_client_private.key` ✓
  - `bnm_test/bnm_test_client.csr` ✓
  - `bnm_test/bnm_test_client_signed_certifcate.crt` ✓
  - `bnm_test/bnm_test_client_public.key` ✓
  - `bnm_test/bnm_test_client_openssl.cnf` ✓
  - `bg_register_bnm_test.rb` ✓ (prepared for next retry)
- Public key for registration uploads: `./secrets/qseal/guide_2026-04-07-bnm-test-bg-originalish-01/bnm_test/bnm_test_client_public.key`
- Certificate fingerprint (latest): `79:B8:71:79:BA:CC:E6:FF:EC:70:D9:EC:98:04:D7:3A:43:0D:25:BF:6E:90:8F:3C:F6:D6:E9:B1:34:11:C8:94`
- Subject (latest): `CN=BNM TEST TEST TPP, O=TEST-TPP-BNM TEST, C=MD, ST=Fake street, organizationIdentifier=TEST-TPP-BNM TEST`
- Issuer (latest): `CN=SIS CA Authority, O=FakeCA, C=MD, ST=Fake street`
- Serial (latest): `5F5C152445732A553EDA4287DAEC4262C0BC3C49`
- Validity (latest): `Apr 7 15:41:39 2026 GMT` → `Apr 2 15:41:39 2027 GMT`
- OpenSSL version used: `OpenSSL 3.6.1 27 Jan 2026`
- Key/cert consistency: private key modulus matches certificate modulus (MD5 `f2e69f9f9e7b3e76aaa61b60ee1e3ced`)
- Profile: near-original `bg_cert_gen.sh` semantics preserved — CA DN unchanged (`SIS CA Authority` / `FakeCA`), client DN template unchanged (`CN = $out_name TEST TPP`, `O = TEST-TPP-$out_name`, `organizationIdentifier = TEST-TPP-$out_name`), `basicConstraints=CA:TRUE`, placeholder `qcStatements`.
- Fix applied vs the strict original script: removed only the `oid_section` alias blocks that fail on OpenSSL 3 and separated display name (`BNM TEST`) from file slug (`bnm_test`) so the generated certificate uses the intended company name while local file paths remain stable.
- Historical note: earlier runs reused `texpert-v2` and overwrote artifacts in place.
- Current policy: strict one-attempt-one-folder rule; all new runs must use a fresh attempt folder.

## Procedure (Guide-aligned)

### 1) Prepare local secure folder
```bash
ATTEMPT_ID="guide_$(date +%F)-<attempt-tag>"
ATTEMPT_DIR="./secrets/qseal/$ATTEMPT_ID"

# Strict: do not overwrite previous attempts
if [ -e "$ATTEMPT_DIR" ]; then
  echo "ERROR: attempt folder already exists: $ATTEMPT_DIR"
  echo "Create a new <attempt-tag> and retry."
  exit 1
fi

mkdir -p "$ATTEMPT_DIR"
chmod 700 "$ATTEMPT_DIR"
cd "$ATTEMPT_DIR"
```

### 2) Generate CA and Client private keys
```bash
openssl genrsa -out ca_private.key 2048
openssl genrsa -out client_private.key 2048
chmod 600 ca_private.key client_private.key
```

### 3) Create CA config (`ca_openssl.cnf`)
> **Note:** `CN` must match the legal entity name used in the client cert subject — set it to the same value as the client cert `CN` so `issuer=CN=...` in the signed certificate matches expectations.

```ini
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = Texpert Bank
O = Texpert Bank S.A.
C = MD
ST = Chisinau

[ cert_ext ]
subjectKeyIdentifier=hash
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth,serverAuth
```

### 4) Create CA CSR and self-signed CA certificate
```bash
openssl req -config ca_openssl.cnf -new -key ca_private.key -nodes -out ca.csr
openssl x509 -signkey ca_private.key -in ca.csr -req -days 365 -out ca_certificate.crt
chmod 600 ca.csr ca_certificate.crt
```

### 5) Create Client config (`client_openssl.cnf`)
> **Note:** `organizationIdentifier` must use the standard PSD2 format `PSDXX-NCA-ID` (e.g. `PSDMD-BNM-99999`). Do not use `oid_section` aliasing — use the built-in OID `2.5.4.97` mapping in OpenSSL 3.x.

```ini
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha256
distinguished_name = dn
req_extensions = cert_ext

[ dn ]
CN = Texpert Bank
O = Texpert Bank S.A.
C = MD
ST = Chisinau
organizationIdentifier = PSDMD-BNM-99999

[ cert_ext ]
basicConstraints = CA:TRUE
subjectKeyIdentifier = hash
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
qcStatements = "ASN1:UTF8String:...statement PSP_AS PSP_AI PSP_PI PSP_IC"
```

### 6) Create Client CSR
```bash
openssl req -config client_openssl.cnf -new -key client_private.key -nodes -out client.csr
chmod 600 client.csr
```

### 7) Sign Client CSR with self-signed CA
```bash
openssl x509 -req -days 360 -extfile client_openssl.cnf -extensions cert_ext -in client.csr \
 -CAcreateserial -CA ca_certificate.crt -CAkey ca_private.key -out client_signed_certifcate.crt
chmod 600 client_signed_certifcate.crt ca_certificate.srl
```

### 8) Validate and capture metadata
```bash
openssl version
openssl x509 -in client_signed_certifcate.crt -noout -subject -issuer -serial -startdate -enddate
openssl x509 -in client_signed_certifcate.crt -noout -fingerprint -sha256
openssl x509 -in client_signed_certifcate.crt -noout -text | grep -E "Subject:|organizationIdentifier|qcStatements|X509v3"
```

### 9) Verify certificate via Salt Edge TPP Verifier (PEM string input)
The API expects the certificate as a **PEM string** in `data.certificate`.
Use the dedicated script (reads `.env` automatically):

```bash
script/tpp_verifier_check.sh
```

Or manually:

```bash
ATTEMPT_ID="guide_YYYY-MM-DD-<attempt-tag>"
ATTEMPT_DIR="./secrets/qseal/$ATTEMPT_ID"
CERT_PATH="$ATTEMPT_DIR/client_signed_certifcate.crt"
APP_ID="<your_tpp_verifier_app_id>"
APP_SECRET="<your_tpp_verifier_app_secret>"

PAYLOAD=$(jq -Rn --arg cert "$(cat "$CERT_PATH")" '{data:{certificate:$cert}}')

curl -sS -o /tmp/tpp_verifier_response.json -w "%{http_code}\n" \
  -H "App-Id: $APP_ID" \
  -H "App-Secret: $APP_SECRET" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "https://priora.saltedge.com/api/tpp_verifiers/v2/certificates"

cat /tmp/tpp_verifier_response.json | jq .
```

Expected successful result:
- HTTP `200`
- `data.certificate.fingerprint` present
- `data.eligible` and `data.mode` present

If credentials are invalid/missing:
- Non-200 response (for example `404` with `TppVerifierClientNotFound`)
- Treat this as an environment credential blocker, not a certificate-format failure

Error classification quick guide:
- `TppVerifierClientNotFound` -> **credential-scope** (wrong `App-Id`/`App-Secret`)
- `WrongRequiredFields` -> **payload/certificate-content scope**

Note from Option B test:
- Artea sandbox `Test credentials (Oauth)` values (`Username`/`Password`/`OTP`) were tested and are **not** valid TPP Verifier `App-Id`/`App-Secret` credentials.
- These OAuth creds are for sandbox user/auth flows, not verifier client connection details.

## Notes from Actual Run
- For OpenSSL `1.1.1d+` and `3.x`, you must not add `oid_section` alias blocks for `organizationIdentifier` (`2.5.4.97`); this OID is built-in and aliasing it fails with `oid exists`.
- Keep all other config fields unchanged and ensure these alias lines are absent in local files:
  - `oid_section = my_oid`
  - `[ my_oid ]` + `organizationIdentifier=2.5.4.97`
  - `oid_section = OIDs`
  - `[ OIDs ]` + `organizationIdentifier = 2.5.4.97`
- Local execution on this machine without alias blocks produced the expected cert outputs.

## Evidence Scope (Do/Do Not)

### Record in repo
- SHA-256 fingerprint
- Subject / issuer / serial
- Validity dates
- Observed OID-related fields and extension presence (`organizationIdentifier`, `qcStatements`)
- OpenSSL version used

### Never record in repo
- Private key content
- Full CSR body content
- PKCS#12 contents/passphrases
- Any raw secret env values

## Milestone 2 Exit Criteria Check
- Certificate chain ready: self-signed CA cert + signed client cert generated locally. **COMPLETED (2026-04-09)**
- Certificate fingerprint ready: extracted and recorded in `docs/tpp_registration_log.md` and `docs/tpp_register_artifacts/2026-04-09-texpert/analysis.md`.
- Secret handling respected: no key/CSR/P12 content committed to git.
- TPP Verifier success (`HTTP 200`) with valid verifier client credentials: **pending** (requires `App-Id`/`App-Secret` from Priora connection details or provisioning).

Artifacts (canonical)
- Safe extracted docs view: `docs/tpp_register_artifacts/2026-04-09-texpert/texpert/`
- Canonical full secret bundle (git-ignored): `./secrets/qseal/guide_2026-04-09-texpert/texpert.zip`
- Attempt scripts used (non-destructive copy): `script/attempts/guide_2026-04-09-texpert/bg_cert_gen.sh`, `script/attempts/guide_2026-04-09-texpert/bg_register.rb`

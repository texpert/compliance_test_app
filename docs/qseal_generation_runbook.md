# QSEAL Generation Runbook

## Goal
Generate sandbox-compatible certificate artifacts for Salt Edge TPP registration using the guide flow, with all secret material kept outside git.

## Canonical Source
- `docs/certificate_generation_guide.md`
- `docs/agents/secrets.md`

## Local Execution Record (Milestone 2)
- Execution date: `2026-04-04`
- Execution path (outside repo): `$HOME/secrets/saltedge/qseal/guide_2026-04-04`
- Output files generated locally:
  - `ca_private.key`
  - `ca.csr`
  - `ca_certificate.crt`
  - `client_private.key`
  - `client.csr`
  - `client_signed_certifcate.crt`
  - `client_public.key`
  - `ca_certificate.srl`
- Public key used for registration uploads: `$HOME/secrets/saltedge/qseal/guide_2026-04-04/client_public.key`

## Procedure (Guide-aligned)

### 1) Prepare local secure folder
```bash
mkdir -p "$HOME/secrets/saltedge/qseal/guide_2026-04-04"
chmod 700 "$HOME/secrets/saltedge/qseal/guide_2026-04-04"
cd "$HOME/secrets/saltedge/qseal/guide_2026-04-04"
```

### 2) Generate CA and Client private keys
```bash
openssl genrsa -out ca_private.key 2048
openssl genrsa -out client_private.key 2048
chmod 600 ca_private.key client_private.key
```

### 3) Create CA config (`ca_openssl.cnf`)
```ini
oid_section = my_oid

[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha1
distinguished_name = dn

[ dn ]
CN = Fake CA Authority
O = Fake CA
C = UK
ST = Fake street

[ cert_ext ]
subjectKeyIdentifier=hash
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth,serverAuth

[ my_oid ]
organizationIdentifier=2.5.4.97
```

### 4) Create CA CSR and self-signed CA certificate
```bash
openssl req -config ca_openssl.cnf -new -key ca_private.key -nodes -out ca.csr
openssl x509 -signkey ca_private.key -in ca.csr -req -days 365 -out ca_certificate.crt
chmod 600 ca.csr ca_certificate.crt
```

### 5) Create Client config (`client_openssl.cnf`)
```ini
oid_section = OIDs

[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha1
distinguished_name = dn
req_extensions = cert_ext

[ dn ]
CN = Fake TPP
O = Fake TPP
C = UK
ST = Fake Street
organizationIdentifier = PGB-123

[ cert_ext ]
basicConstraints = CA:TRUE
subjectKeyIdentifier = hash
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
qcStatements = "ASN1:UTF8String:...statement PSP_AI PSP_PI PSP_CI..."

[ OIDs ]
organizationIdentifier = 2.5.4.97
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

```bash
CERT_PATH="$HOME/secrets/saltedge/qseal/guide_2026-04-04/client_signed_certifcate.crt"
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
- The guide's `oid_section` aliasing for `organizationIdentifier` can trigger an OpenSSL conflict on some versions (`oid exists`).
- If that happens, keep all other config fields unchanged and remove only these lines from local files before retry:
  - `oid_section = my_oid`
  - `[ my_oid ]` + `organizationIdentifier=2.5.4.97`
  - `oid_section = OIDs`
  - `[ OIDs ]` + `organizationIdentifier = 2.5.4.97`
- Local execution on this machine used that compatibility fallback and still produced the expected cert outputs.

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
- Certificate chain ready: self-signed CA cert + signed client cert generated locally.
- Certificate fingerprint ready: extracted and recorded in `docs/tpp_registration_log.md`.
- Secret handling respected: no key/CSR/P12 content committed to git.
- TPP Verifier success (`HTTP 200`) with valid verifier client credentials: **pending** (currently blocked by `TppVerifierClientNotFound`).

# QSEAL Generation Runbook

## Goal
Generate sandbox-compatible QSEAL certificate artifacts for Salt Edge TPP registration without storing secret key material in git.

## References
- `docs/Certificate Generation Guide.pdf`
- `docs/agents/secrets.md`
- `docs/tpp_discovery_notes.md` (certificate expectations and open questions)

## Preconditions
- OpenSSL is installed locally (`openssl version`).
- You have a private local directory outside the repository for certificate artifacts.
- You reviewed `docs/agents/secrets.md` and confirmed no key/cert files will be committed.
- You know the sandbox subject values to use for your organization:
  - Common Name (CN)
  - `organizationIdentifier` (example format: `PSDE-BaFin-123456`)

## Output Artifacts (local only)
Store all generated files outside this repository (example: `~/secrets/saltedge/qseal/`):
- `qseal_private.key` (private key, encrypted)
- `qseal_request.csr` (certificate signing request)
- `qseal_cert.pem` (test certificate)
- `qseal_bundle.p12` (optional PKCS#12 bundle)

## Procedure

### 1) Prepare secure local folder
```bash
mkdir -p "$HOME/secrets/saltedge/qseal"
chmod 700 "$HOME/secrets/saltedge/qseal"
```

### 2) Generate encrypted private key (RSA 3072)
```bash
openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:3072 \
  -aes-256-cbc \
  -out "$HOME/secrets/saltedge/qseal/qseal_private.key"

chmod 600 "$HOME/secrets/saltedge/qseal/qseal_private.key"
```

### 3) Create OpenSSL extension config for PSD2 roles
```bash
cat > "$HOME/secrets/saltedge/qseal/qseal_openssl_ext.cnf" <<'EOF'
[ req ]
default_md = sha256
prompt = no
distinguished_name = dn
req_extensions = req_ext

[ dn ]
C = DE
O = Example TPP GmbH
CN = Example TPP QSEAL
organizationIdentifier = PSDE-BaFin-123456

[ req_ext ]
keyUsage = critical, digitalSignature, nonRepudiation
extendedKeyUsage = clientAuth
certificatePolicies = @polsect

[ polsect ]
policyIdentifier = 0.4.0.19495.2
CPS.1 = "https://example.invalid/psd2-policy"
userNotice.1 = @notice

[ notice ]
explicitText = "PSD2 roles: PSP_AI"
EOF

chmod 600 "$HOME/secrets/saltedge/qseal/qseal_openssl_ext.cnf"
```

### 4) Generate CSR
```bash
openssl req -new \
  -key "$HOME/secrets/saltedge/qseal/qseal_private.key" \
  -out "$HOME/secrets/saltedge/qseal/qseal_request.csr" \
  -config "$HOME/secrets/saltedge/qseal/qseal_openssl_ext.cnf"

chmod 600 "$HOME/secrets/saltedge/qseal/qseal_request.csr"
```

### 5) Issue sandbox test certificate
Use one of the following:

- If Salt Edge sandbox provides signing flow, submit `qseal_request.csr` there and save the issued certificate as `qseal_cert.pem`.
- If self-signed certs are accepted in sandbox, generate a temporary self-signed cert:

```bash
openssl x509 -req \
  -in "$HOME/secrets/saltedge/qseal/qseal_request.csr" \
  -signkey "$HOME/secrets/saltedge/qseal/qseal_private.key" \
  -days 365 \
  -sha256 \
  -extfile "$HOME/secrets/saltedge/qseal/qseal_openssl_ext.cnf" \
  -extensions req_ext \
  -out "$HOME/secrets/saltedge/qseal/qseal_cert.pem"

chmod 600 "$HOME/secrets/saltedge/qseal/qseal_cert.pem"
```

### 5b) Import and verify CA chain (sandbox-issued certificates)
If the sandbox returns an intermediate/root chain, keep it local and verify before registration.

```bash
# Example files from portal or issuer
# - qseal_cert.pem (leaf)
# - qseal_intermediate.pem
# - qseal_root.pem

cat \
  "$HOME/secrets/saltedge/qseal/qseal_intermediate.pem" \
  "$HOME/secrets/saltedge/qseal/qseal_root.pem" \
  > "$HOME/secrets/saltedge/qseal/qseal_ca_chain.pem"

chmod 600 "$HOME/secrets/saltedge/qseal/qseal_ca_chain.pem"

openssl verify \
  -CAfile "$HOME/secrets/saltedge/qseal/qseal_ca_chain.pem" \
  "$HOME/secrets/saltedge/qseal/qseal_cert.pem"
```

If the issuer provides DER/P7B formats, convert them to PEM first:

```bash
openssl x509 -inform DER -in "$HOME/secrets/saltedge/qseal/qseal_intermediate.der" -out "$HOME/secrets/saltedge/qseal/qseal_intermediate.pem"
openssl pkcs7 -print_certs -in "$HOME/secrets/saltedge/qseal/qseal_chain.p7b" -out "$HOME/secrets/saltedge/qseal/qseal_chain_from_p7b.pem"
```

### 6) Export optional PKCS#12 bundle for portal upload
```bash
openssl pkcs12 -export \
  -inkey "$HOME/secrets/saltedge/qseal/qseal_private.key" \
  -in "$HOME/secrets/saltedge/qseal/qseal_cert.pem" \
  -name "saltedge-qseal" \
  -out "$HOME/secrets/saltedge/qseal/qseal_bundle.p12"

chmod 600 "$HOME/secrets/saltedge/qseal/qseal_bundle.p12"
```

### 7) Capture metadata for project docs (safe to store in git)
```bash
openssl version
openssl x509 -in "$HOME/secrets/saltedge/qseal/qseal_cert.pem" -noout -subject -issuer -serial -startdate -enddate
openssl x509 -in "$HOME/secrets/saltedge/qseal/qseal_cert.pem" -noout -fingerprint -sha256
openssl x509 -in "$HOME/secrets/saltedge/qseal/qseal_cert.pem" -noout -text | grep -E "Subject:|Subject Alternative Name|Policy|1\.3\.6\.1\.5\.5\.7\.3\.2|0\.4\.0\.19495"
openssl x509 -in "$HOME/secrets/saltedge/qseal/qseal_cert.pem" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256
```

Record only non-secret metadata in `docs/tpp_registration_log.md` and `docs/qseal_generation_runbook.md` troubleshooting notes:
- SHA-256 fingerprint
- Serial number
- Validity period (`notBefore`, `notAfter`)
- Subject OIDs observed (including PSD2 OIDs)
- OpenSSL version used to generate and inspect the certificate

## Record vs Never Record

### Safe to record in repository docs
- SHA-256 certificate fingerprint
- Certificate subject/issuer and serial number
- Validity period (`notBefore`, `notAfter`)
- Subject OIDs and PSD2-related policy OIDs present in certificate details
- OpenSSL version used for generation/inspection
- Public certificate algorithm and key size
- High-level error messages and resolutions

### Never store in repository docs
- Private key content (`*.key`)
- PKCS#12 file content or passphrase
- Full unredacted CSR if it contains sensitive internal identifiers
- Raw environment secret values (`SE_*` secret content)

## Verification Checklist
- Private key exists only in local secure directory outside git.
- Key and cert files have restrictive permissions (`600`).
- Certificate fingerprint has been recorded.
- Subject includes expected identity fields and `organizationIdentifier`.
- Certificate contains required PSD2 policy OID and expected key usage extensions.
- If issuer chain is provided, CA chain was imported and `openssl verify` succeeds.
- OpenSSL version used is recorded with metadata notes.
- Optional `.p12` bundle opens successfully with expected passphrase.
- `git status` shows no certificate or key material tracked.

## Secure Storage Notes
See `docs/local_qseal_storage.md` for local-only storage policy.

## Troubleshooting Log
| Timestamp | Step | Error | Resolution |
|---|---|---|---|

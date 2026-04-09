# Certificate Generation Guide

In order to generate a self-signed certificate you need the following elements:
- CA Private Key - represents a private key of a fake Certificate Authority, used to sign the CA Certificate
- CA Certificate - represents a certificate of a fake Certificate Authority, used to sign Client's Certificate
- Signature Request (CSR)
- Client Private Key - represents a private key of a fake TPP certificate.

To generate all these elements and sign a fake TPP certificate, follow these steps.

## 1) Generate CA and Client private keys
```bash
openssl genrsa -out ca_private.key 2048
openssl genrsa -out client_private.key 2048
```

## 2) Generate OpenSSL configuration for CA CSR
Create a file named `ca_openssl.cnf` with:

```ini
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha256
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
```

## 3) Create CA CSR
```bash
openssl req -config ca_openssl.cnf -new -key ca_private.key -nodes -out ca.csr
```

## 4) Create CA self-signed certificate from CA CSR
```bash
openssl x509 -signkey ca_private.key -in ca.csr -req -days 365 -out ca_certificate.crt
```

## 5) Generate OpenSSL configuration for Client CSR
Create a file named `client_openssl.cnf` with:

```ini
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha256
distinguished_name = dn
req_extensions = cert_ext

[ dn ]
C = UK
O = Fake TPP
organizationIdentifier = PGB-123
CN = Fake TPP
ST = Fake Street

[ cert_ext ]
basicConstraints = CA:TRUE
subjectKeyIdentifier = hash
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
qcStatements = "ASN1:UTF8String:...statement PSP_AS PSP_AI PSP_PI PSP_IC"
```

> OpenSSL compatibility rule: on OpenSSL `1.1.1d+` and `3.x`, you must not add manual OID alias blocks for `2.5.4.97` (`organizationIdentifier`). This OID is built-in, and alias blocks fail with `OBJ_create: oid exists`.

## 6) Create Client CSR
```bash
openssl req -config client_openssl.cnf -new -key client_private.key -nodes -out client.csr
```

## 7) Sign Client CSR by self-signed CA
```bash
openssl x509 -req -days 360 -extfile client_openssl.cnf -extensions cert_ext -in client.csr \
 -CAcreateserial -CA ca_certificate.crt -CAkey ca_private.key -out \
 client_signed_certifcate.crt
```

## 8) Check certificate validity and information
This can be done using Salt Edge TPP Verifier service:
- https://priora.saltedge.com/docs/tpp_verifier#certificates-verify-v2

For more information:
- https://priora.saltedge.com/docs/tpp_verifier#certificates-verify

## 9) TLS Cipher Suite Policy (PSD2 API)

> Source: https://priora.saltedge.com/docs/tpp_verifier#changelog (announced 23 Dec 2021, effective 3 Feb 2022)

### Removed (no longer supported)
```
TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384
TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256
```

### Supported cipher suites
```
TLS_AES_256_GCM_SHA384          (TLS 1.3)
TLS_CHACHA20_POLY1305_SHA256    (TLS 1.3)
TLS_AES_128_GCM_SHA256          (TLS 1.3)
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384      (TLS 1.2)
TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (TLS 1.2)
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256      (TLS 1.2)
```

### Compatibility with generated certificates

All supported TLS 1.2 suites use `ECDHE-RSA-*` — meaning RSA keys are used for **authentication** (signing), not for key exchange. The RSA 2048-bit key generated in these steps is fully compatible with all listed suites.

Verified on this setup:
- Certificate signature algorithm: `sha256WithRSAEncryption`
- Public key: `RSA 2048 bit`
- All 6 supported suites confirmed available via `openssl ciphers -v`

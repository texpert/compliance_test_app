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

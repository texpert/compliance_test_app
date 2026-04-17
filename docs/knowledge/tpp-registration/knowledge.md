# TPP Registration — Confirmed Knowledge

## QSeal Certificate Structure

A QSeal (Qualified Electronic Seal) certificate is an X.509 certificate that encodes PSD2 compliance
claims via the `qcStatements` extension (OID `1.3.6.1.5.5.7.1.3`), defined in ETSI EN 319 412-5 and
ETSI TS 119 495.

### Mandatory eIDAS Statement
The certificate must include a statement declaring it as a Qualified Electronic Seal:

| OID | Short name | Meaning |
|-----|-----------|---------|
| `0.4.0.1862.1.2` | id-etsi-qct-eseal | Declares the cert as a Qualified Electronic Seal under eIDAS Annex III |

This statement has no `statementInfo` value — it is a bare OID in a `SEQUENCE`.

### PSD2 Role Statement
The PSD2-specific statement uses OID `0.4.0.19495.2` (`id-etsi-psd2-qcStatement`) with a
`PSD2QcType` value containing:

1. `RolesOfPSP` — a `SEQUENCE OF RoleOfPSP`, each containing:
   - `roleOfPSPOid OBJECT IDENTIFIER` — the PSD2 role OID
   - `roleOfPSPName UTF8String` — the human-readable role code
2. `nCAName UTF8String` — name of the National Competent Authority that licensed the TPP
3. `nCAId UTF8String` — identifier of the NCA

### PSD2 Role OIDs (ETSI TS 119 495)

| OID | Role Code | Description |
|-----|-----------|-------------|
| `0.4.0.19495.1.1` | PSP_AS | Account Servicing Payment Service Provider (banks/ASPSPs) |
| `0.4.0.19495.1.2` | PSP_PI | Payment Initiation Service Provider (PISP) |
| `0.4.0.19495.1.3` | PSP_AI | Account Information Service Provider (AISP) |
| `0.4.0.19495.1.4` | PSP_IC | Card-based Payment Instruments Issuer (CBPII) |

A single TPP certificate commonly carries multiple roles (e.g., PSP_AI + PSP_PI for a fintech that
reads accounts and initiates payments).

### Subject Identity Attribute

| OID | Name | Meaning |
|-----|------|---------|
| `2.5.4.97` | organizationIdentifier | Unique registration number assigned by the NCA to the TPP |

This OID is built-in to OpenSSL 1.1.1d+ and 3.x — do **not** re-declare it in CNF alias blocks.

## Ruby Implementation (openssl gem)

The openssl gem bundled with Ruby 3.x supports constructing `OpenSSL::ASN1::ObjectId` from dotted
OID notation for OIDs not registered in OpenSSL's built-in database (added in openssl gem 2.1.0).

```ruby
OpenSSL::ASN1::ObjectId.new('0.4.0.19495.1.3')  # works on Ruby 3.x
```

The `qcStatements` extension must be assembled manually as raw DER because OpenSSL's
`ExtensionFactory` does not know the ETSI-specific OIDs. Use `OpenSSL::ASN1::Sequence` and
`OpenSSL::X509::Extension.new(oid, der_bytes, critical)`.

## Trust Service Provider Name (tsp_name)

The `tsp_name` identifies the entity that **issued** the QSeal certificate — not the TPP company
that owns the certificate.

In production, this is a Qualified Trust Service Provider (QTSP): a regulated body listed on the
EU Trusted List (EUTL) that has been independently audited to issue qualified certificates. The QTSP
vouches for the TPP's identity and PSD2 roles under eIDAS.

### For test / sandbox certificates

When the certificate is self-signed by a locally generated CA, the `tsp_name` should reflect that
it is a test artifact. Derive it from the **CN** (or **O**) of the signing CA certificate's subject
DN so it stays consistent with the `Issuer DN` field embedded in the signed certificate. Never
use the TPP company name — that is the certificate *subject*, not the issuer.

**Source rule:** `tsp_name = CN of CA certificate subject` (fallback to O, then Certificate#name).

Example: if the CA certificate has `CN=SaltEdge CA Authority, O=SaltEdgeCA, C=RO`, then
`tsp_name = "SaltEdge CA Authority"`.

### Why consistency matters

Any relying party (e.g., a payment gateway or verifier) that validates the certificate chain will
compare the `Issuer DN` in the signed cert against a trusted list. Storing the CA's CN in
`tsp_name` makes it straightforward to trace which CA signed each QSeal cert without parsing PEM.

## DB Storage

`QsealCertificate#qc_statement_data` stores the selected PSD2 role codes as a JSON array
(e.g., `["PSP_AI", "PSP_PI"]`). The OID details are embedded in the certificate's `qcStatements`
extension; the DB column is for auditing and fast role-based lookups without parsing the certificate.

`QsealCertificate#tsp_name` stores the CN (or O) from the signing CA certificate's subject DN.
For test certs this will be something like `"SaltEdge CA Authority"`; for production it would be
the QTSP's legal name as it appears on the EUTL.

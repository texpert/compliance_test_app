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

## DB Storage

`QsealCertificate#qc_statement_data` stores the selected PSD2 role codes as a JSON array
(e.g., `["PSP_AI", "PSP_PI"]`). The OID details are embedded in the certificate's `qcStatements`
extension; the DB column is for auditing and fast role-based lookups without parsing the certificate.

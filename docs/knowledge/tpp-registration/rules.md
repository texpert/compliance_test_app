# TPP Registration — Rules

## Certificate Generation

- Always generate a 2048-bit RSA client private key; smaller keys are rejected by PSD2 APIs.
- The `organizationIdentifier` subject field (OID `2.5.4.97`) must be included in the CSR; it
  carries the NCA-assigned TPP registration number. Do not redeclare this OID in OpenSSL CNF alias
  blocks on OpenSSL 1.1.1d+ — it is built-in and will fail with `OBJ_create: oid exists`.
- The `qcStatements` extension (OID `1.3.6.1.5.5.7.1.3`) must be built as raw DER because
  OpenSSL's `ExtensionFactory` does not understand ETSI OIDs.

## Role Selection

- A QSeal certificate must contain at least one PSD2 role OID (`0.4.0.19495.1.x`).
- PSP_AI (`0.4.0.19495.1.3`) is the minimum required role for AIS (account information) flows.
- Always include both the eIDAS eseal statement (`0.4.0.1862.1.2`) and the PSD2 statement
  (`0.4.0.19495.2`) in the certificate's qcStatements extension.

## DB Conventions

- Store selected role codes (e.g., `["PSP_AI", "PSP_PI"]`) in `qc_statement_data` (JSON column) —
  never store OIDs directly; the human-readable codes are sufficient for auditing.
- `tsp_name` must be derived from the **CN** (fallback: O) of the signing CA certificate's subject
  DN — **not** from the TPP company name. The TSP is the issuer, not the subject. Using the CA's CN
  keeps `tsp_name` consistent with the `Issuer DN` embedded in the signed certificate PEM.

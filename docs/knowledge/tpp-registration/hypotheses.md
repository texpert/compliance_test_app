# TPP Registration — Hypotheses

## Unverified

- **NCA name/ID format**: The `nCAName` and `nCAId` fields in the PSD2 qcStatement may need to
  match the exact strings expected by the Salt Edge Priora sandbox verifier. Currently using
  `'SaltEdge Test NCA'` / `'SALTEDGE-TEST'` as placeholders — not confirmed to be accepted.

- **Certificate chain validation**: Priora's TPP verifier may validate that the signing CA
  certificate is trusted. It is unknown whether a locally generated self-signed CA passes their
  validation or whether the CA must be pre-registered.

- **QSCD declaration**: Whether the sandbox requires `id-etsi-qcs-QcSSCD` (OID `0.4.0.1862.1.4`)
  to be included in qcStatements is not confirmed. Omitting it currently.

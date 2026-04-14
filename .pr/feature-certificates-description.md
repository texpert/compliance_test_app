# Certificates Feature: Models, Migrations, Encryption, and Tests

## Overview
This pull request introduces a robust certificates subsystem to the Salt Edge Compliance demo app, including:
- Database migrations for certificates, CA certificates, and QSeal certificates
- Models for Certificate, CaCertificate, QsealCertificate, and Provider associations
- Transparent encryption for certificate private keys using Rails Active Record Encryption
- Comprehensive model specs using RSpec and shoulda-matchers

## Key Changes
- **Migrations:**
  - Adds `certificates`, `ca_certificates`, and `qseal_certificates` tables with all required fields, indexes, and foreign keys
- **Models:**
  - Implements `Certificate` (with AASM state machine, delegated_type, and encryption)
  - Implements `CaCertificate` and `QsealCertificate` (with correct associations)
  - Updates `Provider` for new associations
- **Testing:**
  - Adds shoulda-matchers for concise model specs
  - All new and existing model specs pass (`bin/rspec`)
- **Security:**
  - Follows centralized secrets policy ([docs/agents/secrets.md](docs/agents/secrets.md))
  - Certificate private keys are encrypted at rest

## Compliance & Quality
- Follows [AGENTS.md](AGENTS.md) guidance:
  - Uses a dedicated feature branch and PR ([Workflow](docs/agents/workflows.md))
  - Adheres to secrets management ([Secrets Policy](docs/agents/secrets.md))
  - Comprehensive testing and verification ([Testing](docs/agents/testing.md))
  - Rails/RSpec conventions ([Conventions](docs/agents/conventions.md))
  - Quality gate and review cadence ([Quality Gate](docs/agents/quality_gate.md))

## Migration
- Run `bin/rails db:migrate` to apply new tables

## Verification
- Run `bin/rspec` to verify all tests pass

---

Please review for correctness, security, and compliance. See [AGENTS.md](AGENTS.md) for further details on workflow and quality standards.

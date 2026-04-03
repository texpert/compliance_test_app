# Quality Criteria

Please review these initial criteria.

## Category: Sandbox integration safety
## Criteria:
- Secrets and certificate private keys are not committed to git.
- Callback and redirect configuration stays consistent with documented `SE_*` environment variables.
## Severity: blocking
## Source: Salt Edge sandbox integration workflow and repo secret-handling rules
## Last triggered: never

## Category: Verification and evidence
## Criteria:
- Changes that affect behavior are verified with the relevant local command (`bundle exec rspec`, lint, or documented checks).
- Documentation is updated when setup, test, or integration workflows change.
## Severity: warning
## Source: Current Rails/RSpec workflow and AGENTS documentation rules
## Last triggered: never

## Category: Scope alignment
## Criteria:
- Disabled Rails frameworks are not re-enabled unless the task explicitly requires them.
- Integration mismatches and observed sandbox issues are recorded in the corresponding `docs/` files.
## Severity: warning
## Source: Current app baseline and integration documentation structure
## Last triggered: never

# Conventions

## App Baseline
- Rails version target: `8.1.3`.
- Ruby version target: `3.4.9` (`.tool-versions`).
- Test framework: `rspec-rails`.

## Test Conventions
- Require `rails_helper` centrally in `spec/spec_helper.rb`.
- Do not add `require 'rails_helper'` in individual spec files unless a one-off exception is explicitly justified.

## Framework Scope (Intentionally Disabled)
In `config/application.rb`, keep these commented out unless a task explicitly needs them:
- `active_storage`
- `action_cable`
- `action_text`
- `action_mailbox`
- `rails/test_unit`

## Repo Rules
- Follow [secrets.md](./secrets.md) for what counts as a secret and how to handle it.
- Run `bin/rubocop` before every commit; do not commit if any offenses are reported.
- Follow [workflows.md](./workflows.md) commit and PR description rules for every commit and every PR update.

## Documentation Rules
- Keep runnable commands in `README.md` aligned with actual scripts/binaries.
- Keep integration evidence and mismatch notes in `docs/` files, not in commit messages.

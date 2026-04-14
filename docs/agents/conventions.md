# Conventions

## App Baseline
- Rails version target: `8.1.3`.
- Ruby version target: `3.4.9` (`.tool-versions`).
- Test framework: `rspec-rails`.

## Ruby File Pragma
- Every Ruby file must start with `# frozen_string_literal: true` as the first line, unless there is a documented exception.

## Test Conventions
- Require `rails_helper` centrally in `spec/spec_helper.rb`.
- Do not add `require 'rails_helper'` in individual spec files unless a one-off exception is explicitly justified.
- Treat per-file `require 'rails_helper'` as a regression unless explicitly approved.

## Runtime Conventions (Strong)
- Prefer `Time.now.utc` over `Time.current` for persisted flow/audit timestamps to avoid timezone drift across environments.
- Prefer non-exception control flow in application logic (`find_by` + explicit handling) over exception-driven flow (`find`/`find_by!`) unless raising is part of the contract.

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

## FactoryBot Usage
- Use `FactoryBot` factories for all model creation in specs. Do not use direct `.create!` or `.new` for `Company`, `User`, `Provider`, or any model with a factory defined, unless a test requires explicit attribute control.
- Prefer `create(:model)` or `build(:model)` for test setup. Use traits and associations to express variations.
- Define all new factories in `spec/factories/` and keep them minimal and reusable.
- Do not duplicate factory declarations in individual specs; use top-level `let` declarations in the outermost `describe` block to DRY test setup.
- If a test requires a custom instance, use `build(:model, attr: ...)` or `create(:model, attr: ...)` with explicit attributes.
- Always include `config.include FactoryBot::Syntax::Methods` in `rails_helper.rb` for concise syntax.

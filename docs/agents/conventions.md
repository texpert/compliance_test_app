# Conventions

## App Baseline
- Rails version target: `8.1.3`.
- Ruby version target: `3.4.9` (`.tool-versions`).
- Test framework: `rspec-rails`.

## Framework Scope (Intentionally Disabled)
In `config/application.rb`, keep these commented out unless a task explicitly needs them:
- `active_storage`
- `action_cable`
- `action_text`
- `action_mailbox`
- `rails/test_unit`

## Repo Rules
- Do not commit local secrets (`.env`, private cert/key files).
- Use `.env.example` for env var shape and keep actual values local.

## Documentation Rules
- Keep runnable commands in `README.md` aligned with actual scripts/binaries.
- Keep integration evidence and mismatch notes in `docs/` files, not in commit messages.

# Testing

## Baseline Test Command
```bash
bin/rspec
```
`bin/rspec` enforces `RAILS_ENV=test` unconditionally. Always use this instead of `bundle exec rspec` directly.

## Expected Verification for App Changes
- Run `bin/rspec` before opening a PR.
- If a change affects setup or test commands, update `AGENTS.md`, this file, and `README.md` in the same PR.
- Follow forced verification rules in [mechanical_overrides.md](mechanical_overrides.md) before reporting completion.

## Related Verification Commands
```bash
bin/rails zeitwerk:check
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
```

## CI Parity
- RSpec is the local test baseline.
- Lint and security checks are defined in `.github/workflows/ci.yml`.
- Keep command names here aligned with CI and project binstubs.

## Current Test Scope
- Primary test framework: `rspec-rails`.
- `rails/test_unit` is intentionally disabled in `config/application.rb`.
- Add focused specs close to the behavior being introduced.

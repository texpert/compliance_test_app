# Testing

## Baseline Test Command
```bash
bundle exec rspec
```

## Expected Verification for App Changes
- Run `bundle exec rspec` before opening a PR.
- If a change affects setup or test commands, update `AGENTS.md`, this file, and `README.md` in the same PR.

## Related Verification Commands
```bash
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

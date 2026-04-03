# AGENTS Guide

Salt Edge Compliance demo app: Rails 8.1.3 + RSpec for simulating AIS flow with supporting compliance documentation.

## Essentials (Read First)
- Package manager: Bundler (`bundle install`). Runtime tool manager: `mise` (`ruby 3.4.9` in `.tool-versions`).
- Core local commands:
  - `mise install`
  - `bundle install`
  - `bin/rails db:prepare`
  - `bundle exec rspec`
- Workflow rule: do not work directly on `main`; use dedicated branches and open PRs.
- Keep secrets out of git (`.env`, certificate keys); use `.env.example` and local `config/certs/*` paths.

## Progressive Guidance
- Workflow and branch/PR flow: [`docs/agents/workflows.md`](./docs/agents/workflows.md)
- Testing and verification: [`docs/agents/testing.md`](./docs/agents/testing.md)
- Rails/RSpec conventions and repo rules: [`docs/agents/conventions.md`](./docs/agents/conventions.md)
- Salt Edge integration scope and boundaries: [`docs/agents/integrations.md`](./docs/agents/integrations.md)
- Candidates to remove from legacy guidance: [`docs/agents/deletion_candidates.md`](./docs/agents/deletion_candidates.md)

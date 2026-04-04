# Workflows

## Local Setup
```bash
mise install
bundle install
bin/rails db:prepare
```

## Verification Pointer
- Test and verification commands live in `docs/agents/testing.md`.

## CI Parity Notes
- CI runs security scans and lint from `.github/workflows/ci.yml`:
  - `bin/brakeman --no-pager`
  - `bin/bundler-audit`
  - `bin/rubocop -f github`

## Branch and PR Flow
- Start from updated `main`.
- Create a dedicated branch per task.
- Push branch and open PR into `main`.
- Keep commits focused and reviewable.

## Task Start / Finish Checklist
- Before starting a new domain task, review relevant files from `knowledge/` and prior records in `decisions/`.
- While working, test whether any existing hypothesis can be confirmed or contradicted.
- Before marking a task complete, evaluate it against `quality/criteria.md`.
- See deeper guidance in `docs/agents/knowledge_architecture.md`, `docs/agents/decision_journal.md`, and `docs/agents/quality_gate.md`.
- Apply execution constraints from `docs/agents/mechanical_overrides.md` (step-0 cleanup, phased execution, edit integrity).

## When to Update Agent Docs
- If setup commands change, update `AGENTS.md`, this file, and `README.md` in the same PR.
- If test commands change, update `docs/agents/testing.md`, `AGENTS.md`, and `README.md` in the same PR.
- If CI commands change, update this file to match `.github/workflows/ci.yml`.

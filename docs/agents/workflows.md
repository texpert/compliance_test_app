# Workflows

## Local Setup
```bash
mise install
bundle install
bin/rails db:prepare
```

## Verification Pointer
- Test and verification commands live in [testing.md](testing.md).

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

## PR Description Rules
- PR descriptions are mandatory; do not open or leave a PR with an empty description.
- PR descriptions must summarize changes at a general level (what changed and why), not commit-by-commit.
- PR descriptions must include: scope summary, reason/rationale, and explicit follow-up scope if work is split across PRs.
- PR descriptions must include one sentence on user-visible impact (or explicitly state there is no user-visible impact).
- PR descriptions must not include a `Files Changed` section.
- PR descriptions must not include test example/failure counts.
- PR descriptions must not describe how verification was performed (commands run, environments used, or step-by-step validation details).
- PR descriptions must not reference commit SHAs or commit history in the description.

## Commit Message Rules
- Commit messages are mandatory and must be descriptive enough to explain intent, not just file movement.
- Use concise conventional prefixes where possible (for example: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`).
- Commit messages must describe the behavior or policy change, not implementation trivia.
- Do not use placeholder commit messages (for example: `update`, `wip`, `fix stuff`, `misc`).
- Before finalizing any commit message, ensure it matches the scope of the staged diff.

## Task Start / Finish Checklist
- Before starting a new domain task, review relevant files from `docs/knowledge/` and prior records in `docs/decisions/`.
- While working, test whether any existing hypothesis can be confirmed or contradicted.
- Before marking a task complete, evaluate it against [criteria.md](../quality/criteria.md).
- See deeper guidance in [knowledge_architecture.md](knowledge_architecture.md), [decision_journal.md](decision_journal.md), and [quality_gate.md](quality_gate.md).
- Apply execution constraints from [mechanical_overrides.md](mechanical_overrides.md) (step-0 cleanup, phased execution, edit integrity).

## When to Update Agent Docs
- If setup commands change, update `AGENTS.md`, this file, and `README.md` in the same PR.
- If test commands change, update [testing.md](testing.md), `AGENTS.md`, and `README.md` in the same PR.
- If CI commands change, update this file to match `.github/workflows/ci.yml`.

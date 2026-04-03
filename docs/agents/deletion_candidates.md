# Deletion Candidates Tracker

This file is a working backlog for AGENTS-doc cleanup decisions. Items are only removed when a PR marks them `Resolved` with evidence.

## Process
1. Add candidate with `Open` status.
2. In a PR, choose `delete`, `rewrite`, or `keep`.
3. Link evidence (updated file path) and set `Resolved`.
4. Remove fully resolved items in a later docs cleanup pass if history is no longer needed.

## Status Legend
- `Open`: needs decision.
- `Deferred`: valid candidate, postponed.
- `Resolved`: decision applied in repo.

## Current Candidates (Legacy AGENTS)
| Candidate | Category | Status | Decision | Evidence |
|---|---|---|---|---|
| "Run `list_dir` + `git ls-files` before coding" | Redundant | Resolved | Deleted from root guidance | `AGENTS.md` |
| "Create minimal project skeleton first" | Redundant | Resolved | Deleted (no longer matches repo stage) | `AGENTS.md` |
| "Keep changes small and explicit" | Too vague | Resolved | Deleted (not actionable) | `AGENTS.md` |
| "Prefer adding missing project contracts early" | Too vague | Resolved | Deleted (stale for current baseline) | `AGENTS.md` |
| "Do not assume language tooling until manifests exist" | Obvious/generic | Resolved | Deleted (manifests now exist) | `AGENTS.md`, `docs/agents/workflows.md` |
| "Add integration notes near first implementation" | Obvious/generic | Resolved | Replaced by concrete docs map | `docs/agents/integrations.md` |
| "Repo is scaffold only with `.git/` and `.idea/`" | Contradiction | Resolved | Removed and replaced with current essentials | `AGENTS.md` |
| "No tracked source files / README / test harness / CI" | Contradiction | Resolved | Removed and replaced with current workflows | `AGENTS.md`, `docs/agents/workflows.md` |
| "No project-defined build or test commands" | Contradiction | Resolved | Removed and replaced with verified commands | `AGENTS.md`, `README.md` |
| "No internal or external integrations discoverable" | Contradiction | Resolved | Replaced with Salt Edge integration scope | `docs/agents/integrations.md` |

## Template for New Candidates
| Candidate | Category | Status | Decision | Evidence |
|---|---|---|---|---|
|  | Redundant / Too vague / Obvious / Contradiction | Open |  |  |

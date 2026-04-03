# AGENTS Guide

## Current Repository Reality
- This repository is currently a scaffold: only `.git/` and `.idea/` are present.
- `git ls-files` currently returns no tracked source files.
- No `README.md`, build manifest, test harness, or CI config is discoverable yet.
- One conventions scan (`**/{.github/copilot-instructions.md,AGENT.md,AGENTS.md,CLAUDE.md,.cursorrules,.windsurfrules,.clinerules,.cursor/rules/**,.windsurf/rules/**,.clinerules/**,README.md}`) found no prior AI guidance files before this one.

## What Agents Should Do First
- Treat this as an unbootstrapped project; start by identifying the intended stack from user direction or newly added manifests.
- Before coding, run a quick inventory (`list_dir` + `git ls-files`) to confirm whether new files appeared.
- If asked to implement features, create the minimal project skeleton first (manifest, source dir, test dir, README) and keep structure explicit.

## File/Directory Conventions Observed Here
- `.idea/` exists; avoid editing IDE state unless explicitly requested.
- Prefer leaving `.idea/workspace.xml` untouched (machine-local state).
- If IDE config must be changed, keep edits to stable files such as `.idea/.gitignore` or project-level settings only.

## Build/Test/Debug Workflow (Current)
- There are no project-defined build or test commands yet.
- Do not assume language tooling (`npm`, `pytest`, `go test`, etc.) until corresponding manifests exist.
- When bootstrapping, add runnable scripts/tasks immediately and document them in `README.md`.

## Integration Points
- No internal service boundaries or external API integrations are currently discoverable.
- Add integration notes near first implementation (for example in `README.md` or `docs/architecture.md`) so future agents can follow concrete boundaries.

## Agent Execution Pattern for This Repo
- Keep changes small and explicit while repository intent is still forming.
- Prefer adding missing project contracts early: dependency manifest, entrypoint, tests, and developer commands.
- After each non-trivial addition, verify with the newly introduced test/build command and update this file with concrete, repo-specific workflows.

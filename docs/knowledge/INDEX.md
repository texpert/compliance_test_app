# Knowledge Index

Use this index to route agents to active domain knowledge folders.

## Domains
- `docs/knowledge/salt_edge_ais/` — Salt Edge AIS flow, sandbox behaviors, compliance integration patterns
  - `knowledge.md`: populated M1 — confirmed BG spec endpoints, headers, signing, SCA flow
  - `hypotheses.md`: populated M1 — base URL version, SCA auto-approve, callback params, cert validation
  - `rules.md`: populated M1 — X-Request-ID, Digest, no-commit-keys, state validation, consent status check, log filtering

## Folder Contract
Each domain folder must contain these three files:
- `knowledge.md` — confirmed facts and observed patterns
- `hypotheses.md` — ideas that need more evidence before acting on them
- `rules.md` — confirmed patterns to apply by default (promoted from hypotheses)

## Future Domain Conventions
When adding a new domain folder:
1. Create `docs/knowledge/{domain}/` with all three required files above.
2. Add an entry to this index with a one-line description.
3. Use lowercase hyphenated names (e.g., `docs/knowledge/aspsp-dashboard/`, `docs/knowledge/tpp-registration/`).

Suggested future domains as the project grows:
- `docs/knowledge/tpp-registration/` — certificate setup, sandbox registration patterns, error observations
- `docs/knowledge/aspsp-dashboard/` — dashboard behavior, sandbox UI patterns
- `docs/knowledge/berlingroup-api/` — Berlin Group protocol behaviors, quirks, and confirmed patterns

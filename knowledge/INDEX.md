# Knowledge Index

Use this index to route agents to active domain knowledge folders.

## Domains
- `knowledge/salt_edge_ais/` — Salt Edge AIS flow, sandbox behaviors, compliance integration patterns

## Folder Contract
Each domain folder must contain these three files:
- `knowledge.md` — confirmed facts and observed patterns
- `hypotheses.md` — ideas that need more evidence before acting on them
- `rules.md` — confirmed patterns to apply by default (promoted from hypotheses)

## Future Domain Conventions
When adding a new domain folder:
1. Create `knowledge/{domain}/` with all three required files above.
2. Add an entry to this index with a one-line description.
3. Use lowercase hyphenated names (e.g., `knowledge/aspsp-dashboard/`, `knowledge/tpp-registration/`).

Suggested future domains as the project grows:
- `knowledge/tpp-registration/` — certificate setup, sandbox registration patterns, error observations
- `knowledge/aspsp-dashboard/` — dashboard behavior, sandbox UI patterns
- `knowledge/berlingroup-api/` — Berlin Group protocol behaviors, quirks, and confirmed patterns

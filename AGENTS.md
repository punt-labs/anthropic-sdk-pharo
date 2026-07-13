# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Session Completion

This repo does **not** push to `main`. Code is committed via Iceberg
inside the Pharo image, pushed from the CLI (`git push` — never
Iceberg's in-image push), and always landed through a pull request.

For the authoritative workflow — Iceberg/Tonel discipline, the
`make lint` / `make test` gates, and the branch → PR → merge
lifecycle — follow [CLAUDE.md](CLAUDE.md): see its **Git Integration**
and **Development Model** sections, plus the org-wide **Workflow /
Lifecycle** guidance it inherits.

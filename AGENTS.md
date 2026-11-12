# Agent Instructions

## Issue tracking

Read `.punt-labs/punt/CLAUDE.md` before planning or writing to the issue
tracker. Linear is the tracker of record where this repo is migrated.
Beads is a local mirror there and the tracker of record elsewhere.

This repo is migrated: Linear (the Punt Labs team, issues labelled
`repo:aspharo`) is the record, and `bd` is a read-mostly mirror.

## Quick Reference

```bash
bd config get linear.pull_label   # Must print repo:aspharo before any pull
bd linear sync --pull-if-stale --relations --team c1dfbb2c-985e-40cf-b004-5127646efc9d
bd ready --label-any repo:aspharo --exclude-label deferred   # Find available work
bd show <id>                                                 # View issue details
```

Claim work (In Progress) and complete it (Done) in Linear, never with a
local `bd` edit; a by-id pull (`bd linear sync --pull --issues <PL id>
--team <id>`) refreshes the bead afterwards. There is no beads sync step.

## Session Completion

This repo does **not** push to `main`. Code is committed via Iceberg
inside the Pharo image, pushed from the CLI (`git push` — never
Iceberg's in-image push), and always landed through a pull request.

For the authoritative workflow — Iceberg/Tonel discipline, the
`make lint` / `make test` gates, and the branch → PR → merge
lifecycle — follow [CLAUDE.md](CLAUDE.md): see its **Git Integration**
and **Development Model** sections, plus the org-wide **Workflow /
Lifecycle** guidance it inherits.

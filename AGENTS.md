# Agent Instructions

## Issue tracking

Read `.punt-labs/punt/CLAUDE.md` before planning or writing to the issue
tracker. Linear is the tracker of record: the Punt Labs team (`PL`), issues
labelled `repo:aspharo`.

Create, claim (In Progress), finish (Done) and cancel issues in Linear, with
the `repo:aspharo` label plus a type label (`Bug`, `Feature`, `Improvement`,
`Epic`).

## Session Completion

This repo does **not** push to `main`. Code is committed via Iceberg
inside the Pharo image, pushed from the CLI (`git push` — never
Iceberg's in-image push), and always landed through a pull request.

For the authoritative workflow — Iceberg/Tonel discipline, the
`make lint` / `make test` gates, and the branch → PR → merge
lifecycle — follow [CLAUDE.md](CLAUDE.md): see its **Git Integration**
and **Development Model** sections, plus the org-wide **Workflow /
Lifecycle** guidance it inherits.

# COE: SQLite3 bootstrap conflict (2026-11-26)

## Impact

Starting November 23, 2026, the
[test](https://github.com/punt-labs/anthropic-sdk-pharo/actions/runs/45249998068)
and [lint](https://github.com/punt-labs/anthropic-sdk-pharo/actions/runs/45249997860)
jobs on `main` failed in `make setup` before any SDK tests or lint ran.
Retrying setup with an image saved by the failing recipe can fail again.

## Root cause

[Postern #40](https://github.com/punt-labs/postern/pull/40) added
`Postern-Observe` to the default load. It brought in PuntObserve, which
registered SQLite3 at commit `44dee15` via `github://`. SDK setup then
requested the same SQLite3 revision from its pinned local Git checkout.
Metacello treats the two repository locations as conflicting even though
they refer to the same revision.

## Fix

[PR #66](https://github.com/punt-labs/anthropic-sdk-pharo/pull/66) loads the
pinned observability dependencies first. It refreshes Postern from a
pinned local checkout and lets Postern reuse the loaded dependencies.
Neither the lint nor the test gate changed. Use `make rebuild` to recover
an image left by the failing setup.

## Prevention

When updating bootstrap dependency pins, review the transitive baseline
changes and run `make setup` from a fresh `pharo/` directory. Also rerun
setup on an existing image when updating Postern, to catch stale
baseline registrations and package lists.

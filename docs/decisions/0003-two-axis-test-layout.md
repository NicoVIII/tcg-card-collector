# 0003 — Two-level test layout cut on two different axes

- Status: accepted
- Date: 2026-06-14 (backfilled 2026-07-08)

## Context

Hexagonal + functional-core/imperative-shell architecture creates exactly
three things that need verifying per bounded context (the assembled context
through its driving port, the pure driver mappers, the driven adapters
against real-ish infra) — but the *hard logic* worth fast targeted tests can
sit in any layer. One folder axis cannot express both "what coverage is owed"
and "where the hard bit lives" without lying about one of them.

## Considered options

- **Single unified axis** (mirror source tree, or classic unit/integration/e2e
  pyramid) — forces the mandatory-coverage set and the supplementary
  fast-feedback set into one taxonomy; empty folders become ambiguous
  (owed-and-missing vs. nothing-to-test).
- **Two levels on two axes** — `process/` cut by architectural role
  (mandatory; an empty folder means a test is owed and missing), `unit/` cut
  by source location (supplementary; folders must be earned, no placeholders).

## Decision

Adopt the two-axis layout: `test/<context>/process/{application,driver,infrastructure}/`
for the coverage the architecture owes, `test/<context>/unit/` mirroring
source paths for targeted fast-feedback tests. Full rationale and the
per-level rules: [server/test/README.md](../../server/test/README.md);
operating rules: `server/test/AGENTS.md`. Do not unify the axes.

## Consequences

- Empty `process/*` folders are kept deliberately as visible debt markers;
  empty `unit/*` folders are forbidden — the same signal means opposite
  things per level, which is exactly why the README exists.
- Contract tests, subcutaneous tests, and e2e are explicitly deferred, not
  forgotten (recorded in the README's deferred section).
- The layout costs nothing mechanically (gleeunit discovers everything);
  the nesting is purely for humans.

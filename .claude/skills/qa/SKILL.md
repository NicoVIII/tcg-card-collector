---
name: qa
description: >
  Dual-mode QA grounded in this project's settled test strategy — test-quality
  judgement over written tests, plus exploratory verification of the running app
  against real behaviour. Use when asked to "review the tests", "QA this", design a
  test plan or verification charter for a feature, or verify that a path actually
  works (not just compiles). Placement and layout questions are NOT relitigated
  here — server/test/AGENTS.md owns those.
---

You are doing QA for this codebase in one of three modes. Pick by what was asked:

- **Consult** — a feature is being designed or built: advise on the test approach
  and/or design a verification charter before code exists.
- **Review** — tests already exist: judge their quality. Read-only; report, do not
  edit.
- **Verify** — exercise the running app to establish whether a path actually works.

All three anchor on `server/test/AGENTS.md` (two-axis layout, what is owed, what
never to test) and `client-web/AGENTS.md` (colocated tests, node-only environment).
Those documents own test *placement and mechanics* — reference them, never restate
or relitigate them. This skill owns test *quality* and verification *practice*.

## Test-quality invariants (consult + review)

**Assertions must pin behaviour.** A test earns its keep by asserting the return
value and the resulting state (fake state at the application level, DB state at the
infrastructure level). "Didn't crash", shape-only, or tautological assertions are
flagged with the same severity as a missing test.

**Coverage is judged, never measured.** No coverage percentages — not as a target,
not as a verdict, not as a radar. Sufficiency is a judgement: the owed `process/`
tests exist and assert meaningfully; complex pure domain logic earned a
property-based `unit/` test; inputs cover the boundaries the types cannot enforce
(empty, duplicates, ordering edges, the collector-number-style "10 before 2" traps).

**Every genuine bug is owed a repro test — at the lowest level that can express
it.** Failing test before or with the fix, usually example-based in `unit/` per the
existing convention. If the only honest repro would need a deferred layer (e2e,
contract tests, subcutaneous), do not force an awkward substitute — name it
explicitly as an accepted gap in the report. Never skip silently.

**Inherited prohibitions.** Everything `server/test/AGENTS.md` forbids demanding is
forbidden here too: no tests for what types guarantee, no mocks/spies/call-order,
no wiring tests, no demanding the deferred layers. A behaviour-preserving refactor
that breaks a test indicts the test.

## Verification invariants (consult + verify)

**Environment — hard rule.** The dev DB (`server/db/tcg-card-collector.db`) holds
real collection data. Read-only probes against the live dev instance are fine.
Anything that mutates state runs against a scratch copy: copy the db file, start a
second server instance with `TCG_DB_FILE=<copy> PORT=<free port>` (defaults:
`db/tcg-card-collector.db`, 8080), exercise there, delete the copy after. No
exceptions, including "it's probably idempotent".

**Evidence standard.** "Verified" requires both the behaviour observed through a
real interface AND the persisted state inspected (sqlite3 against the relevant
tables) — never a status code or a log line alone. Every verdict ends with an
explicit statement of what was NOT covered.

**Drivers.** API-first: the parallel REST API (ADR 0004) plus direct DB inspection
covers backend paths cheaply. Client-side-derived behaviour — placement guidance
(ADR 0006), query-cache invalidation — does not exist at the API and MUST be
exercised in the browser; skipping it silently is the one unforgivable verification
sin. Playwright is available as disposable hands for that: scripts are throwaway,
never committed as tests, never wired into CI. The e2e deferral in
`server/test/AGENTS.md` stands; this skill does not erode it by accretion.

**Charter shape.** A verification charter names: the path under test, the risk that
motivates it, the environment (live read-only vs scratch), the steps, the expected
observations (interface + state), and the edges worth probing while there.

## Outputs

- **Defects** go through the established review-pass triage flow: triage first,
  then GitHub issues labelled bug / foundation / enhancement. Trivial fixes may be
  suggested inline; do not fix during a verify run.
- **Verdicts** are ephemeral: reported in conversation as verified / not verified /
  partially verified, with evidence cited and gaps named. No verification log is
  maintained.

## How to report

**Review mode** — findings grouped by severity, each with a `path:line` reference
and a concrete change:

- **Missing owed tests / untrustworthy assertions (must fix)**
- **Weak spots that will compound (should fix)** — thin edges, missing property
  tests on hard logic, repro gaps
- **Accepted gaps to acknowledge** — things only a deferred layer could express

End with a one-line verdict on whether the suite would actually catch the next
regression in the reviewed area.

**Verify mode** — per charter: what was exercised, evidence observed (interface +
state), defects found (triaged per above), gaps explicitly named.

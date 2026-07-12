# 0009 — The database is a boundary: constraints owed, STRICT tables everywhere

- Status: accepted
- Date: 2026-07-12

## Context

Domain invariants are enforced by parsing at boundaries into typed values
(opaque Gleam types, ADR 0008). If the application were the database's only
writer, DB-level constraints would be re-validation. But it isn't: the catalog
bulk load shells out to the sqlite3 CLI (ADR 0005), migrations and manual
surgery edit the file directly, and the SQLite file outlives any given version
of the app. SQLite's default type affinity compounds this — an `INTEGER`
column happily stores text.

The question surfaced during the 2026-07-12 QA verification work, which also
demonstrated the failure class: writers outside the app's type system reaching
tables whose declared types nothing enforced.

## Considered options

- **Types own invariants, DB minimal** — no CHECKs beyond PK/NOT NULL;
  trusts "the app is the only writer", which is factually false here.
- **Structural constraints only** — PKs/uniqueness in the DB, value rules
  (CHECKs) only in code; leaves affinity's silent type coercion open.
- **DB as boundary** — invariants are parsed on the way into the DB too:
  NOT NULL, CHECKs, real-identity PKs, and STRICT tables so mistyped values
  fail loudly at insert instead of settling in silently.
- Within STRICT adoption: **new tables only** (drift-prone mixed schema) vs
  **sweep now** (one migration, one verification effort).

## Decision

The database is treated as a boundary. Every table is STRICT (migration 0014
swept the existing ones), and new tables carry NOT NULL, value CHECKs, and
primary keys that encode real identity. Absence of these on a new table is a
review finding, not a style choice. Operating rules live in
`server/AGENTS.md`; design judgement in the data-migrations skill.

## Consequences

- Malformed data fails at insert time with a clear error — including through
  the sqlite3 CLI bulk path, which was verified against a real ~115k-row
  Scryfall dump before the sweep landed.
- Value CHECKs duplicate domain rules by design; when a domain rule changes,
  the corresponding CHECK needs a migration in the same change.
- Both SQLite implementations in play (CLI, esqlite NIF) must stay ≥ 3.37;
  older tooling cannot open a STRICT schema.
- Table-shape changes require the recreate-and-copy dance (SQLite cannot
  ALTER to STRICT), which migration 0014 already paid for the existing corpus.

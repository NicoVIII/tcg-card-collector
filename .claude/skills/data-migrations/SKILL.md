---
name: data-migrations
description: >
  Dual-mode schema and migration design for the SQLite database — table shape, DB-level
  invariants, dbmate migration quality, and the bulk-load exception. Use when designing
  or changing tables ("add a table", "new migration", "schema change"), before running
  destructive migrations, and when reviewing anything under server/db/migrations/ or the
  DAOs' SQL.
---

You are the data engineer for this codebase, in one of two modes. Pick by what was
asked:

- **Consult** — schema or a migration is being designed: shape it before it exists;
  draft the migration when concrete beats abstract.
- **Review** — migrations or DAO SQL changed: judge them. Read-only; report, do not
  edit.

Settled mechanics live elsewhere — reference, never restate: sqlight with `?`
placeholders and typed decoders for all SQL (`server/AGENTS.md`), except the one
documented bulk-load exception (`sqlite3 .import`, ADR 0005 — do not "fix" it back).
Migrations run via `just dbmate-migrate`; db path comes from `TCG_DB_FILE`.

## Locked invariants

**The DB is a boundary — constraints are owed.** The database file outlives the app and
admits other writers (sqlite3 CLI, future versions, manual surgery), so invariants are
parsed on the way into it too: new tables carry NOT NULL, CHECKs for value invariants
(`quantity > 0`, status enums), and PKs that encode real identity. A new table missing
them is a finding, not a style choice.

**STRICT tables, everywhere.** New tables are declared STRICT; the pre-STRICT tables
are being swept in a dedicated migration series (commissioned 2026-07-12), not left to
incidental touches. The bulk-load path is the risk surface: any STRICT change to a
table that `.import` feeds must be verified against a real Scryfall dump before it
lands.

**Downs are schema-faithful, data-lossy.** Every migration ships a `migrate:down` that
exactly restores the previous schema; lost data stays lost. Downs are a dev-loop tool —
the production upgrade story is forward-only. Review checks up/down schema symmetry,
never data round-trips.

**Data destruction requires a dead concept and a backup.** An up may drop data only
when the domain model no longer owns the concept, and must first migrate forward
everything any context still owns (the 0008 precedent: seed the living collection, then
drop the import-history tables). Before a destructive migration touches a real DB, the
db file gets copied; a missing backup step in the plan is a finding.

**Context isolation extends into the database.** Every table is owned by exactly one
bounded context; no SQL statement reads another context's tables and no foreign key
crosses contexts — cross-context data flows through Gleam facades via application
ports, full stop. The module linter cannot see into SQL strings, so this skill is the
enforcement.

## Conventions (derived from the existing corpus — keep them)

- `NNNN_snake_case.sql` naming, `-- migrate:up` / `-- migrate:down` blocks.
- Dates/timestamps are ISO-8601 TEXT; ids are TEXT UUIDs; card identity is the natural
  composite key `(set_code, collector_number)` — no surrogate ids where a natural key
  exists.
- Data migrations belong inside schema migrations when a shape change requires them
  (0008), and a migration doing something non-obvious explains *why* in a comment
  (0009's derived-not-stored note).
- Indexes are added for demonstrated read paths, not speculatively.

## How to report

**Consult mode** — the proposed schema/migration with the invariants that shaped it
named inline, the drafted SQL, and the operational plan stated when destructive:
what's migrated forward, what dies, where the backup copy goes. If a request would
store what the domain says must stay derived, or would cross context ownership, say so
before designing around it.

**Review mode** — findings grouped by severity, each with a `path:line` reference and a
concrete change:

- **Boundary violations (must fix)** — missing constraints or STRICT on new tables,
  cross-context SQL/FKs, string-built SQL outside the ADR 0005 exception, missing or
  asymmetric downs.
- **Risks (should fix)** — destructive steps without the forward-migration or backup
  plan, speculative indexes, surrogate keys shadowing natural identity.
- **Open calls for the author** — schema shapes that would harden the finish/language
  debt (see the domain-design skill), anything ADR-weight.

End with a one-line verdict on whether the schema is getting stronger or looser as a
boundary.

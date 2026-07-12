# Backend — Agent Rules

Operating rules for the Gleam backend. Full rationale, request-flow diagrams,
and the cross-context dependency diagram live in
[docs/dev/architecture.md](../docs/dev/architecture.md); this is the
actionable subset. Domain vocabulary and context ownership:
read `docs/dev/domain-ubiquitous-language.md` before touching domain code.

## Structure (lint-enforced — violations are build errors)

Context-first, then layer:
`src/<bounded_context>/{domain,application/{commands,queries},infrastructure/{adapters,daos},driver/{skir,http}}/`.
Four contexts: **card_catalog**, **collection**, **inventory_planning**,
**insights**. `just server::lint-check` enforces:

- **Layer ordering**: imports only go inward — `driver`/`infrastructure` may
  import `application` and `domain`, never the reverse.
- **Context isolation**: contexts never import each other, except a consumer's
  `infrastructure/` importing a provider's `driver/gleam/` facade, and only
  for pairs declared in `test/lint.gleam` (`allowed_cross_bc`). Additions must
  be explicit one-to-one pairs; update the diagram in
  `docs/dev/architecture.md` when the list changes.
- **`shared/`** may be imported by any context but imports no context;
  **`bootstrap/`** is the composition root and may import anything.
  `shared/domain/` holds value types only: a type qualifies when more than one
  context needs the same representation and none disputes its semantics —
  orderings, labels, and DSL concerns stay in their context (ADR 0008).
- **Generated code** (`src/shared/driver/skir/skirout/`) — never edit; change
  `skir-src/` and run `just skir-gen`. It is linted like handwritten code;
  only `gleam format` skips it.

## Application Layer (CQRS)

- Commands in `<context>/application/commands/<command>/`, queries in
  `<context>/application/queries/<query>/`; each use case owns its
  `handler.gleam` + `ports.gleam`. Operation-first naming
  (`RefreshCatalogCommand`, `RefreshCatalogPorts`).
- Ports are **capability-narrow** and never shared across use cases: one
  `*Port` type for a single capability, a `*Ports` aggregate record for
  several. Single-op port = `fn`-type alias; cohesive multi-op port = small
  record. Adapters wire one typed function per port, annotated with the port
  type alias.
- **Command handlers own orchestration** — no empty pass-through to a single
  `ports.execute()`. **Query handlers may be one-liners**; don't invent
  branching to avoid looking thin.

## Drivers

- Drivers call use-case handlers directly — no application facade. skir
  mapping in `driver/skir/codec.gleam`; http split into `handler.gleam` +
  `json_codec.gleam`.
- Both transports (skir + REST) are permanent. A use case with
  externally-visible side effects must put that orchestration in one shared
  module both drivers call (e.g. `card_catalog/driver/refresh_launcher.gleam`)
  — never duplicate it per transport.

## Infrastructure & Database

- Network adapters take an injected-IO seam (closure via `new_with_*`
  constructor; `new()` wires the live one) so tests inject fakes without
  touching `composition.gleam`.
- SQLite via `sqlight` through `shared/infrastructure/stores/sqlite_store.gleam`
  — no string-interpolated SQL; `?` placeholders +
  `sqlight.text`/`sqlight.int`/`sqlight.nullable`. Migrations:
  `just dbmate-migrate`; db path from `TCG_DB_FILE`.
- **Migrations don't auto-apply in dev** — run `just dbmate-migrate` after
  pulling or writing one. Boot triggers a catalog refresh, and a stale schema
  fails it mid-import (bit us 2026-07-12: an unapplied migration emptied
  `catalog_sets` before `replace_sets` was made atomic).
- **All tables are STRICT** (migration 0014). New tables declare `STRICT` and
  carry NOT NULL / CHECK / real-identity PKs — the DB is a boundary other
  writers (sqlite3 CLI, manual surgery) can reach, so invariants are parsed on
  the way in too ([ADR 0009](../docs/decisions/0009-db-as-boundary-strict-tables.md)).
- `sqlite_store.exec` opens a fresh connection per call — statements that must
  succeed or fail together go through `sqlite_store.exec_all_atomically`,
  never composed from separate `exec` calls.
- Write ports return `Result(Nil, String)`; read ports are
  `fn() -> Result(a, String)` (or `Result(Option(a), String)` when absence is
  a valid outcome). Never collapse a read error to a default unless every
  consumer provably can't tell the difference; when in doubt, propagate.

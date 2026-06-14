# Infrastructure Layer

Two sub-layers:

- `adapters/` — port implementations. Mirrors the `application/` structure: `adapters/commands/<command>/adapter.gleam`, `adapters/queries/<query>/adapter.gleam`.
- `stores/` — SQLite access helpers, one file per store, shared by adapters within the same context.

When adding a new use case, place its adapter at the path that mirrors the application layer, and its store logic in the context's `stores/` folder.

**Stores hold primitives, not orchestration.** Business-logic flow (branching, sequencing) belongs in the application handler. Stores expose public, single-responsibility functions that the adapter wires into the port.

**Injected-IO seam for testability.** Adapters that make network calls accept a `*IO` record (e.g. `catalog_store.RefreshIO`) holding the outbound I/O as a closure, injected via a `new_with_io(io)` constructor. `new()` calls `new_with_io(live_io())` for production. This lets integration tests pass a hermetic fake without changing `composition.gleam`.

**Catalog import flow.** `catalog_store.import_cards` orchestrates a validate/partition pass: jq projects Scryfall bulk JSON to compact NDJSON (one object per card, 6 fields), Gleam reads the file, validates each row in `parse_card_row`, skips invalid rows with a per-row warning, then writes the valid rows back as CSV for the existing fast sqlite `.import` + atomic full-replace. `simplifile` is the sanctioned library for in-process file I/O.

# Test Strategy — Agent Rules

Operating rules for writing/placing tests in this project. Full rationale lives in `test/README.md`, the decision record in [ADR 0003](../../docs/decisions/0003-two-axis-test-layout.md); this is the actionable subset. Architecture is hexagonal + functional-core / imperative-shell.

## Layout

```
test/<bounded_context>/
  unit/                 Level 1 — targeted tests, any layer; supplementary
    domain/             mirrors src/<bounded_context>/domain/
    ...                 only layers that earned a test
  process/              Level 2 — required for whole-process coverage
    application/        context via driving port, driven ports faked
    driver/             driving-adapter pure mappers (decode/encode)
    infrastructure/     driven adapters vs real-ish infra
```

The two levels are cut on **different axes, intentionally** — `process/` by architectural role (what coverage is owed), `unit/` by source location (where the hard bit lives). Do not unify them.

## `migrations/` — a third area, not a third axis

`test/migrations/` sits beside the per-context trees: seeds in `migrations/seeds/<migration_stem>.sql` (frozen, one per migration, written against the schema one migration earlier), tests as `migrations/migration_<stem>_test.gleam` using `support/test_db.with_seeded_upgrade`. It exists because the migration chain is one flat global sequence, not context-partitioned — see `test/README.md` § "A third area" for the full reasoning. A migration touching a user-authored table (`collection`, `placed_cards`, `inventory_rules`, `inventory_bulk_spec`, `target_sets`) ships a test here, or the release notes say what it loses (the v0.1.0 promise — `.claude/skills/data-migrations/SKILL.md`).

## `test/portability/fixtures/` — frozen export files, one per format version

Same reasoning as `migrations/`: `format_v<N>.json` is a real export, checked
in once and never edited — a format change adds a new fixture rather than
touching an old one (ADR 0019, ADR 0020). `process/infrastructure/format_fixtures_test.gleam`
imports every fixture and asserts the exact resulting state, and re-exports
the current version's fixture to check it reproduces the file byte for byte.
The root `just portability-schema-check` validates every fixture here against
`docs/portability/export.schema.json`, so the schema and the Gleam encoder
can't silently drift apart.

## `process/` — mandatory, three tests the architecture owes

- **`application/`**: enter at the driving **port** (the handler signature) — NOT the HTTP adapter, no request construction/routing/serialization here. Fake driven ports with **in-memory implementations**. Assert on the **return value and the fake's resulting state**. NEVER assert "was `save` called" / spy / verify call-order. Fast, in-memory. This is the single "acceptance" test; it appears once.
- **`driver/`**: test only the **pure** `decode`/`encode` mappers, directly as pure functions. The glue (`decode |> handler |> encode`) gets no behavioral test. (These are pure like Level 1 but live here because Level 2 is organized by role, not by how the test runs.)
- **`infrastructure/`**: driven adapters against real-ish infra (in-memory / temporary DB). Only level that crosses to a real external system.
- Empty `process/*` folder = a test is **owed and missing**. Keep the folders even when empty.

## `unit/` — supplementary, fast feedback only

- Targeted tests for complex/important logic in any layer. NOT required for process coverage.
- **Mirror the source path**: `unit/domain/pricing_test.gleam` ↔ `src/<ctx>/domain/pricing.gleam`.
- **Only create a folder if a layer actually earned a test.** NO empty placeholder folders here — they would lie (unlike `process/`, these tests aren't owed).
- Property-based by default for pure domain logic; example-based for known cases/regressions.

## Every level

- **Never test what types already guarantee** (no "is this a `Result`", no unrepresentable-state tests). Types own shape/illegal-states/exhaustiveness; tests own behavior + boundaries types can't see.
- **Test behavior through the interface, never wiring/internals.** No asserting call order, no mocking to verify calls, no reaching into private state.
- **Behavior-preserving refactor broke a test → delete-and-rewrite by default** (it was coupled to implementation).

## Gleam / gleeunit mechanics

- gleeunit runs every `*_test` module under `test/` wherever it sits — nesting is for humans, costs nothing mechanically.
- Folder names are module-path segments: snake_case, no spaces.
- No free folder/tag-scoped runs; selective running belongs on a **tag**, never encoded in folder names.

## Deferred — do NOT add unless explicitly asked

- **Contract tests** (`fake ≡ real adapter`) — binds `application/` fakes to `infrastructure/` reals. Per-project call.
- **Subcutaneous** (real app + real adapters, entered below HTTP) — often unnecessary if contract tests exist.
- **e2e** — through the real driving adapter. Deferred; keep thin when added.

## Status

v1. Durable: the mirroring rule and the two-level / two-axis split. Volatile: specific `unit/` folders, and the deferred items. Don't freeze; evolve per context.

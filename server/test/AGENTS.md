# Test Strategy — Agent Rules

Operating rules for writing/placing tests in this project. Full rationale lives in `test/README.md`; this is the actionable subset. Architecture is hexagonal + functional-core / imperative-shell.

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

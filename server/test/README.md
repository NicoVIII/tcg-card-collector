# Test Strategy

This document explains how tests are organized in this project and — more importantly — *why*. The layout is not a generic testing convention layered on top; it falls out of the architecture (hexagonal + functional-core / imperative-shell). If you understand the architecture, the test structure should feel inevitable.

Read this once before adding tests. The structure encodes decisions that are easy to undo by accident.

---

## The two levels

Tests are split into two levels. The critical thing to understand is that **the two levels are cut on different axes, on purpose.** They look parallel; they are not. Trying to force them onto one axis is exactly the confusion this document exists to prevent.

| | What it is | Cut by | Required for coverage? |
|---|---|---|---|
| **`unit/`** (Level 1) | Targeted tests for complex or important bits of *any* layer | **Source location** (where the code lives) | No — supplementary |
| **`process/`** (Level 2) | The set of tests that, together, cover the whole process | **Architectural role** (what the architecture owes) | Yes — mandatory |

The reason they differ is that they answer different questions:

- `process/` answers **"what must I cover?"** The architecture creates three distinct things that need verifying, so three distinct tests are owed. They share a level because each is *mandatory for whole-process coverage*, regardless of how fast or slow they run.
- `unit/` answers **"where is the fast test for this hard bit?"** These are not owed by the architecture. They exist for a faster feedback loop and extra confidence on complex or critical logic.

Do not try to make these two share an axis. Keeping them distinct is the whole design.

---

## Directory layout

```
test/<bounded_context>/
  unit/                 Level 1 — targeted tests, any layer; fast feedback; NOT process coverage
    domain/             mirrors src/<bounded_context>/domain/
    ...                 only layers that actually earned a targeted test appear here

  process/              Level 2 — the set required to cover the whole process
    application/        core + domain, driven ingoing-port → outgoing-port, driven ports faked
    driver/             driving-adapter mappers (pure decode/encode)
    infrastructure/     driven adapters against real-ish infrastructure
```

A `test/README` (this file) makes the reasoning explicit so the structure survives the next person — including you in six months.

---

## Level 2 — `process/` (mandatory)

These three tests are not a stylistic choice. The architecture creates exactly three things to verify, so covering the whole process *requires* all three. An empty `process/application/` is not "no tests needed yet" — it is a visible reminder that a test is **owed and missing**.

### `process/application/` — does the assembled context behave correctly?

Drive the whole bounded context through its **driving port** (the use-case / command-or-query handler signature), with all **driven ports faked** using in-memory implementations.

- **Enter at the driving *port*, not the driving *adapter*.** Do not construct HTTP requests or go through routing/(de)serialization here — that pulls the brittle infra edge into every behavioral test and overlaps with e2e. Call the handler function directly.
- **Use in-memory fakes for driven ports; assert on observable outcomes** — the return value and the resulting state of the fake. **Never assert "was `save` called."** Call-order / spy verification is implementation-coupling and is the single thing most likely to make a test break on a behavior-preserving refactor. When that happens the test was coupled to wiring and should be deleted and rewritten, not patched.
- This is the one true "acceptance" / "component" test. It appears **once**, here. (These terms are used inconsistently in the wild; the definition that matters is the one in this sentence.)
- Fast and in-memory.

### `process/driver/` — do the driving adapters map correctly?

The driving adapter does two separable jobs: pure mapping (`decode` request → command, `encode` result → response) and trivial glue wiring them together. Only the mapping is test-worthy, and it is **pure**.

- Test `decode` / `encode` as **pure functions**, directly. `decode` is a parse-don't-validate boundary — exactly an edge the type system can't see — so it is a good property/example target.
- The glue (`decode |> handler |> encode`) is not worth a behavioral test; it is covered by the deferred e2e, or by nothing.

> Note: these tests are *pure functions* and so are technically the same kind as Level 1. They live in `process/` anyway, because the organizing principle of Level 2 is **architectural role / coverage**, not how the test runs. The driving adapter is one of the three things the architecture owes coverage for.

### `process/infrastructure/` — do the driven adapters work against the real thing?

Test each driven adapter (e.g. the Postgres-backed implementation of a `Repo` port) against **real-ish infrastructure** — an in-memory database, a temporary one, or similar.

- This is the only level that crosses to a real external system. It is the slowest and the most valuable for catching adapter bugs.

---

## Level 1 — `unit/` (supplementary)

Targeted tests for the complex or important parts of *any* layer. Their purpose is a fast feedback loop and extra confidence on the hard parts. They do **not** have to cover the whole process — that is `process/`'s job.

- **Mirror the source path** of whatever is under test. `unit/domain/pricing_test.gleam` tests `src/<bounded_context>/domain/pricing.gleam`. This is just the vertical-slice + core/shell layout applied to the test tree: a test sits at the same relative path as its subject, so it is findable by path and survives refactors.
- **Only layers that actually earned a targeted test appear.** If only the domain holds logic complex enough to warrant fast-feedback tests, then `unit/domain/` is the only folder, and that is correct. **No empty placeholder folders here** — unlike `process/`, these tests are not owed, so an empty folder would lie about what coverage is required.
- **Property-based testing by default** for pure domain logic; example-based for specific known cases and regressions.

---

## Things that apply at every level

- **Never test what the type system already guarantees.** No test asserting a `Result` is a `Result`; no test for a state the sum types made unrepresentable. Types own shape, illegal states, and exhaustiveness; tests own behavior and the boundaries types can't see.
- **Test behavior through the interface, never wiring or internals.** A pure function's signature is its contract and is fair game to test directly. The trap is asserting on call order, mocking collaborators to verify calls, or reaching into private/mutable state.
- **When a behavior-preserving refactor breaks a test, default to delete-and-rewrite.** The test was coupled to implementation. (Rare exception: it encoded an invariant you forgot you cared about.)

---

## Mechanics (Gleam / gleeunit)

- gleeunit discovers and runs every `*_test` module under `test/`, wherever it sits. **The nesting here costs nothing mechanically — it is purely for the human reading it.**
- Directory names become part of the module path, so they must be valid: snake_case, no spaces.
- Match the source *module name* too: `unit/domain/pricing_test.gleam` ↔ `src/.../domain/pricing.gleam`.
- gleeunit does not give folder- or tag-scoped runs for free. If you later want to run only the fast levels, that belongs on a **tag** or a custom runner — not encoded into folder names.

---

## Deferred / per-project (not in this layout yet)

These were discussed and intentionally left out for now. Revisit per project.

- **Contract tests** (`fake ≡ real adapter`). `process/application/` trusts a *fake* driven port; `process/infrastructure/` exercises the *real* adapter. Nothing currently proves the two satisfy the same contract — they can drift, and bugs hide in that gap. A contract test is one suite run against both. When adopted, it slots near infrastructure (e.g. `process/infrastructure/contract/`). It is real ceremony, so it is a per-project call.
- **Subcutaneous tests** — real app wired to *real* driven adapters, entered below HTTP. Often made unnecessary by contract tests (if `fake ≡ real` and the context works against the fake, the wired-up real thing works by transitivity). Adopt only if contract tests don't buy enough confidence.
- **e2e tests** — through the real driving adapter, fully wired. Deferred for now; keep thin when added.

---

## Status

This layout is **v1**. The *mirroring rule* and the *two-level / two-axis split* are the durable parts. The specific folders under `unit/` will shift per context as different layers turn out to hold the complex parts, and the deferred items above may get pulled in per project. Evolve it once a couple of contexts exist; don't freeze a half-formed structure.

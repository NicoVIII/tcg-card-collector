# 0001 — Enforce hexagonal layers and bounded-context isolation with a custom lint

- Status: accepted
- Date: 2026-05-31 (backfilled 2026-07-08)

## Context

The backend is organized context-first (DDD bounded contexts) with strict
hexagonal layers inside each context. The project deliberately doubles as an
architecture playground — the boundaries *are* part of the product. Layering
conventions that live only in documentation decay silently: one convenient
cross-context import compiles fine and normalizes the next one.

## Considered options

- **Convention + review only** — zero tooling cost, but boundary erosion is
  exactly the class of drift that review misses once the diff is large, and a
  solo project has no second reviewer.
- **Custom architecture lint** — encode the layer and context rules as a
  `depends_only_on` rule (glinter, via the vendored `gleam-libs` submodule)
  and fail the build on violations.

## Decision

Architecture rules are lint-enforced: `just server::lint-check` runs
`gleam run -m lint` with the rule configured in `server/test/lint.gleam`.
Contexts must not import each other except through the one legal shape
(consumer `infrastructure/` → provider `driver/gleam/` facade) for pairs
explicitly allowlisted in `allowed_cross_bc`. Layer imports only go inward.
`shared/` imports no context; `bootstrap/` is the composition root.

## Consequences

- Boundaries cannot silently decay; a violation is a build error, and every
  cross-context dependency is an explicit, reviewable allowlist entry.
- The lint config is the source of truth; the diagram in
  [architecture.md](../dev/architecture.md) mirrors it and must be kept in
  sync manually.
- The rule engine lives in a vendored submodule (`server/vendor/gleam-libs`),
  so fresh clones need `git submodule update --init`, and fixing gaps in the
  rule itself means changing that submodule — currently the
  Driver→own-BC-Infrastructure exception isn't encoded, so `driver/gleam/`
  files carry a `// nolint: depends_only_on`.

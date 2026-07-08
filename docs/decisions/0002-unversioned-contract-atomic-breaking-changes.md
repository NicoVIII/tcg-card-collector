# 0002 — Unversioned Skir contract; breaking changes land atomically

- Status: accepted
- Date: 2026-05-31 (backfilled 2026-07-08)

## Context

Backend and frontend are connected by a Skir contract (contract-first RPC,
code generated for both sides). Both sides live in this repository and ship
together as one container to a single self-hosted deployment — there is no
fleet of independently-updating clients to stay compatible with.

## Considered options

- **Versioned contract with a deprecation cycle** — the safe default for
  public APIs, but here it would maintain compatibility shims for consumers
  that cannot exist: client and server are never deployed apart.
- **Unversioned contract, breaking changes allowed only atomically** — both
  sides adapt in the same PR, guarded by a snapshot check.

## Decision

The contract is intentionally unversioned. A breaking change is legal only
when contract source (`skir-src/`), regenerated code, the snapshot
(`skir-snapshot.json`), the server `driver/skir/` mappings, and the frontend
request/query/mutation changes all land in the **same PR**, verified by
`just skir-check`. Full procedure: `skir-src/AGENTS.md`.

## Consequences

- No versioning or compatibility-shim maintenance; the generated types keep
  both sides provably aligned at every commit.
- The snapshot check turns accidental contract drift into a CI failure
  instead of a runtime surprise.
- Contract changes make PRs wider (they must cross all layers at once), and
  any future *external* consumer of the RPC API would break this model —
  third-party access is deliberately pointed at the REST API instead (see
  [0004](0004-keep-parallel-rest-api-alongside-skir.md)).

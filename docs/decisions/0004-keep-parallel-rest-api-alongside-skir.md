# 0004 — Keep a parallel REST API alongside the Skir RPC, permanently

- Status: accepted
- Date: 2026-07-02 (backfilled 2026-07-08)

## Context

Skir RPC is the primary, well-typed API and the only one client-web uses.
But third-party or scripted access (curl, cron jobs, other tools) would have
to embed the Skir client to talk to it, which isn't practical — and the
unversioned-contract policy ([0002](0002-unversioned-contract-atomic-breaking-changes.md))
assumes no external RPC consumers exist.

## Considered options

- **Skir only** — one transport to maintain, but locks out scripted/external
  access or forces the contract to grow versioning guarantees.
- **REST only** — universally consumable, but gives up the generated
  end-to-end typing that keeps client and server provably aligned.
- **Both, permanently** — accept two driver implementations per context in
  exchange for typed internal use *and* plain external access.

## Decision

Both transports stay; the REST API is not legacy. Every context ships a
`driver/skir/` and a `driver/http/` door to the same use-case handlers. A use
case with externally-visible side effects (e.g. spawning a background worker)
must put that orchestration in one shared module both drivers call (e.g.
`card_catalog/driver/refresh_launcher.gleam`) — the two doors must behave
identically, they just speak different wire formats.

## Consequences

- Two thin driver layers per context to write and keep behaviorally
  identical; the shared-orchestration rule exists precisely because this
  duplication was once real drift risk.
- Drivers stay mapping-only (codec/json_codec), so the per-transport cost is
  bounded to encode/decode plus glue.
- External consumers get a stable-ish plain-HTTP surface without dragging
  versioning into the Skir contract.

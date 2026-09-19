# 0011 — In-process synchronous event bus for cross-context reconciliation

- Status: accepted
- Date: 2026-09-19

## Context

Removing/decrementing a card from the collection (#58) can drive a `CopyKey`'s
owned quantity below what `placed_cards` already records for it (a user
corrects a mistyped add after having ticked some copies placed). A full
`ImportCollection` replace has the identical hole: a re-import can restate a
key at a lower quantity than what is already placed. Either way, the placed
ledger should not go on claiming more physical copies than are owned.

Collection owns quantities; Inventory Planning owns placement and already
depends on Collection (`allowed_cross_bc` in `server/test/lint.gleam`). The
lint forbids the reverse — Collection must not import Inventory Planning — so
neither `RemoveCards` nor `ImportCollection` can call Inventory Planning
directly to trigger reconciliation.

## Considered options

- **Derive-and-clamp only, no ledger mutation** — lean on the existing
  documented precedent that "Unplaced" is always derived and clamped at zero
  (`docs/dev/domain-ubiquitous-language.md`), and on `guidance.ts`'s existing
  per-location clamp. Every *displayed* number would already self-heal once
  the two commands above join the set of mutations that invalidate the cached
  projection (ADR 0006). Simplest option, but leaves stale rows sitting in
  `placed_cards` permanently for any key whose owned quantity drops below what
  was placed — harmless to today's readers, but a latent inconsistency the
  issue explicitly asks to resolve.
- **Direct cross-context call from Collection** — rejected outright: violates
  the lint-enforced dependency direction (ADR 0001).
- **Client-orchestrated two-call sequence** — the client calls the mutating
  RPC then a new Inventory Planning reconciliation RPC. Keeps the server
  decoupled, but makes an internal consistency concern a client
  responsibility, and every future collection-quantity-changed reaction would
  need its own bespoke second call wired into every caller.
- **In-process event bus** — Collection publishes a fact that owned
  quantities may have shrunk; Inventory Planning subscribes and reconciles
  itself. Chosen.

## Decision

A generic, synchronous, in-process publish/subscribe primitive lives in
`shared/application/event_bus.gleam` (shared kernel: no bounded context
knowledge, so publishing from one context and subscribing from another never
creates a forbidden import). Both `RemoveCards` and `ImportCollection`
publish through this bus after a successful write; Inventory Planning's
`ReconcilePlacedLedgerCommand` is registered as the subscriber. The
subscription is wired in `bootstrap/composition.gleam` — the only module
allowed to import both contexts — which is where the event's producer(s) and
consumer are connected.

The event carries no payload. Reconciliation re-derives everything it needs
from current state (the whole `placed_cards` ledger against the whole
collection, via the existing `collection_api.list_copies()` facade and
`placed_cards_dao.list()`), so the event is a pure "something that can shrink
owned quantity just happened" signal rather than a fact about which keys
changed. This was chosen over passing the affected `CopyKey`s because the
owned-quantity read has no per-key variant today — a per-key event would
still cost a whole-collection read to answer "what is this key's current
quantity", for no savings.

Dispatch is synchronous: `publish` calls each subscriber inline, so
reconciliation completes before the publishing command's response is sent.
No actor, mailbox, or message broker — the project has a single writer
process, so there is nothing async dispatch would buy, and it would cost the
request/response guarantee (a client refetching immediately after the
response could otherwise observe a stale ledger) and a harder-to-test
boundary (no built-in "wait until handled" without extra plumbing).

A subscriber failure is logged and swallowed, not propagated to the
publisher. `RemoveCards`' collection write and the reconcile write are two
separate, non-atomic transactions (each DAO opens its own connection); if
reconciliation failed and the failure were returned as the command's result,
a client seeing an error would have every reason to retry `RemoveCards` —
decrementing the collection a second time for a write that, from the
collection's point of view, already succeeded. Removal is not idempotent, so
a failed response here is a data-loss hazard, not a safe "try again" signal.
Reporting success once the publisher's own write succeeds, and letting a
reconcile failure surface only in the server log, is the safer default for a
concern (ledger tidiness) that is not the client's to retry. `publish`'s
`Result` return is still real plumbing for a future subscriber that wants
stricter guarantees — this wiring simply chooses not to use it that way.

Reconciliation itself needs a policy for *which* location loses a phantom
copy, since a plain quantity change carries no location. For any key whose
placed total exceeds its owned quantity, that key's locations are pruned in
alphabetical order (the only stable ordering already available, with no
`placed_at` timestamp tracked) until the placed total no longer exceeds
owned — an arbitrary but deterministic tie-break, the same shape as
Inventory Planning's existing CopySelector tie-break (ADR 0010).

## Consequences

- Collection stays fully decoupled from Inventory Planning at the import
  level — it depends only on the generic `shared/application/event_bus`
  primitive, never on Inventory Planning's types.
- The bus has exactly one topic (payload-less) and one subscriber today. It
  is designed to hold more of both without new plumbing, but a second event
  is what proves that out — don't add ceremony for a case that doesn't exist
  yet.
- `ReconcilePlacedLedgerCommand` is the first application command in this
  codebase with no transport door (no skir method, no REST route) — it is
  only ever invoked as an event subscriber. That is a deliberate exception to
  "every command has a driver," not an oversight.
- Reconciliation is O(collection) on every `RemoveCards`/`ImportCollection`
  call, not O(affected keys) — acceptable at this project's scale (the same
  full-collection read the projection already performs on every mutation),
  worth revisiting if collection size or call frequency ever makes it not.
- A stale placed-ledger row can persist for up to one publish cycle if
  reconciliation fails; the failure is visible only in the server log, not to
  the client. This is the deliberate trade-off favoring collection-write
  availability and removal idempotency over immediate ledger correctness.
- The alphabetical location tie-break is arbitrary and should be named as
  such wherever a user could notice it (e.g. if a future UI ever shows which
  location's placed count changed as a result of a removal).

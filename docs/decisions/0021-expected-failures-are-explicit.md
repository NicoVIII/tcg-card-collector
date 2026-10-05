# 0021 — Expected failures are explicit, not clamped or ignored

- Status: accepted
- Date: 2026-10-05

## Context

RemoveCards floored each key at zero and silently ignored absent keys: a typo'd
copy removed nothing, an over-removal took everything, and the response and the
client's success note both claimed the staged count was removed (#156). The
"don't error, so correcting a mistyped add needs no exact count" choice lived
only in the handler's doc comment and the ubiquitous-language glossary; no ADR
recorded it.

The deeper problem is general: when an operation can't do what was asked, the
caller has to be told, in a form it can handle.

## Considered options

- **Keep clamping, report what was applied** — the response grows an applied
  count. The caller still has to notice the difference, and a mistyped key
  still "succeeds".
- **Reject the whole batch with an explicit error** — one outcome per request,
  nothing half-applied.

## Decision

Expected failures are modelled explicitly at every layer:

- **Application layer:** a `Result` error variant (e.g. `RemoveCardsError.ExceedsOwned`),
  never a clamp, default, or no-op that hides the failure.
- **Wire, domain outcome the client branches on:** a typed variant of the
  response.
- **Wire, user-input error:** untyped — a message with a bad-request status
  (`PresentedError` with `BadRequest`: Skir `ServiceError` `E400xBadRequest`,
  REST `400`). Skir has no dedicated user-error type; the 400 `ServiceError`
  is its equivalent of a GraphQL user error.
- **Client:** either prevents sending the request (validating against data it
  can read) or handles the rejection in a way the user can act on. The server
  check backs the client's, so a stale page fails loudly.

RemoveCards applies this: an unowned key or a quantity above the owned one
rejects the batch with `ExceedsOwned` → 400. This supersedes the glossary's
"flooring at zero rather than erroring" rule for ManualRemoval.

## Consequences

- The Remove cards panel needs the owned quantities at staging time, via
  `ListCollectionCards`'s new `collector_number` filter combined with `set_code`.
- The owned check and the decrement are separate steps, not one transaction;
  fine for a single-user service, a concurrent writer could still slip between
  them. The DAO's `decrement_cards` itself still clamps; the handler guards it.
- Other write paths that clamp or no-op silently (e.g. placement unmark) are
  not migrated by this ADR; each gets its own issue when it bites.
- AddCards/RemoveCards' `rejected` variant for malformed rows is untouched;
  #45 owns that shape.

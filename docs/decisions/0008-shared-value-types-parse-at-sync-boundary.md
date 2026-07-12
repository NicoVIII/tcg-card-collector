# 0008 — Shared value types; catalog parses enrichment facts at the sync boundary

- Status: accepted
- Date: 2026-07-12

## Context

`CardPrinting` carried its enrichment attributes — `oracle_id`,
`color_identity`, `type_line`, `released_at` — as opaque strings, with an
inline comment declaring that inventory_planning parses them at its port
boundary. That design kept the catalog consumer-ignorant, but the seam was
weakly typed everywhere: the same rarity parser existed three times
(scryfall_mapper, planning's `card_attributes`, plus a serializer in each),
the catalog could not guarantee the integrity of data it stored, and a
malformed value from Scryfall would only surface downstream — as a card
silently failing every predicate and cascading to bulk, with no signal
anywhere. The catalog's own domain code also named its consumer, which is the
knowledge leak that triggered a bounded-context scope review.

A constraint shapes the solution space: the architecture lint (ADR 0001) only
lets a consumer's `infrastructure/` import a provider's `driver/gleam/`
facade. If catalog's *domain* owned the strong types, planning could never
name them in its own signatures without an illegal `card_catalog/domain`
import.

## Considered options

- **Opaque strings, consumers parse (status quo)** — maximally decoupled, but
  parse/serialize logic is duplicated per consumer, storage integrity is
  unverifiable, and source-data defects degrade silently downstream.
- **Facade DTOs** — catalog domain gets strong types, each facade defines
  mirror DTO types, each consumer re-maps to its own domain. Lint-clean and
  fully decoupled, but structurally identical value types get written three
  times per concept — ceremony that erodes the will to keep boundaries at all.
- **Shared kernel (chosen)** — the universal value types live in
  `shared/domain` next to `card_key`, which already set the precedent of a
  cross-context domain type.

## Decision

A context-independent fact of a printing or set — color identity, release
date, oracle id, the rarity enum — is a `shared/domain` value type. The
catalog parses source strings into these types **once, at its sync boundary**
(`scryfall_mapper`); inland code is strongly typed everywhere; weak
representations exist only at storage and transport seams (SQLite columns and
the wire contract stay strings, mapped in adapters/drivers).

A type qualifies for `shared/domain` when more than one context needs the
same *representation* and no context disputes its semantics. **Policy never
moves with it**: planning keeps its rarity ordering (special/bonus below
rare), its land-first `CardType` reduction, its DSL tokens and sort keys —
all as functions over the shared representations. `type_line` stays a raw
string in the catalog because every reduction of a type line is consumer
policy, not a fact.

Parse policy at the sync boundary: a genuinely absent value (reversible or
multi-face layouts expose no top-level `oracle_id`/`type_line`) is modeled as
`Option`/`None`; a present-but-unparseable value rejects the row through the
existing skip-with-reason path (logged with the card id, counted in the
"validated x/y" import log line).

## Consequences

- The DB schema, the skir contract, and the REST payloads are unchanged;
  only in-process types moved. Drivers serialize strong types back to the
  canonical string forms.
- Read-side adapters now parse stored strings into value types, so corrupt
  stored data surfaces as a query error instead of a silently degraded
  attribute. Refreshing the catalog rewrites the table, so recovery is cheap.
- A Scryfall format change (a new rarity word, a sixth color letter, a
  reshaped date) fails loudly at import time instead of silently fattening
  the bulk pile months later.
- `shared/domain` grows and will attract candidates; the qualification rule
  above is the gate. Orderings, labels, and DSL concerns stay in contexts.
- Rejected rows are still only surfaced in logs and the validated-count line;
  the refresh record schema does not carry per-row rejects. Extending it (and
  the contract + UI) is a possible follow-up, not part of this decision.
- Supersedes the opaque-strings design that was documented only as a comment
  in `card_printing.gleam`, predating the ADR process.

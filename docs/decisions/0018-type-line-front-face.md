# 0018 — Type and supertype reduce the type line's front face

- Status: accepted
- Date: 2026-09-24

## Context

The catalog stores Scryfall's top-level `type_line` unchanged (ADR 0008). For
a multi-face card that line holds both faces, e.g. `Sorcery // Land` or
`Legendary Enchantment // Legendary Land`. `card_type_from_type_line` searched
the whole line, land first, so any card with a land back face reduced to
`Land` — `type = land` and `{type}` treated `Bala Ged Recovery // Bala Ged
Sanctuary` as a land, though it's a sorcery everywhere outside the stack and
battlefield. `supertypes_from_type_line` already walked only the leading
words of the line, so in practice it read the front face — but nobody chose
that split; it fell out of the two implementations differing (#134).

Outside the game a double-faced card has only its front face's
characteristics (CR 712.8a). A binder is outside the game: what you see
placing the card is its front. The two reductions need one shared answer to
"which face", not two accidental ones.

## Considered options

- **Front face** — won. Matches CR 712.8a and what the person sorting the
  binder actually sees. `supertypes_from_type_line` already behaved this way;
  this makes `card_type_from_type_line` match it and gives both a stated
  reason instead of an accident.
- **Either face matches** (e.g. an `any_face_type = land` clause) — lost, for
  now. Some collectors do want to store their MDFC lands with their other
  lands. That's a real but separate need — an additional match mode, not a
  fix to what the existing `type`/`supertype` clauses mean. Out of scope
  here; file it separately if wanted.
- **Split the line in the catalog** (store `type_line_front`, or reduce to a
  `CardType` at sync time) — lost. ADR 0008 already settled that the catalog
  stores facts, not policy; which face to read for placement is Inventory
  Planning's decision, and a future consumer might legitimately want the
  other face (see above). Splitting it earlier would bake this choice into a
  shared fact.

## Decision

`card_type_from_type_line` and `supertypes_from_type_line` both reduce only
the part of `type_line` before the first `" // "`. The catalog's stored
`type_line` is unchanged.

Split cards (`Fire // Ice`, Rooms, aftermath) get the front half too. Scryfall's
`layout` isn't synced, so there's no way to distinguish a split card from a
double-faced one from `type_line` alone; the halves of a split card almost
always share a type, and `CardType` is already reduced to one value, so this
approximation is accepted rather than solved.

## Consequences

- `type = land` / `{type}` now place a double-faced or transform card by its
  front face. Existing collections move MDFC and transform-to-land cards out
  of the Land location on their next projection — a one-time visible change,
  noted in the changelog.
- The catalog-gap handling in
  `server/src/inventory_planning/application/queries/projection/handler.gleam`
  (empty `type_line` stays `None`) is untouched — this ADR only changes which
  substring of a non-empty line the two reductions read.
- An either-face clause remains unimplemented; someone who wants MDFC lands
  filed with lands still has no DSL way to say so.

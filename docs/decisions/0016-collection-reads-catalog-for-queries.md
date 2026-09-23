# 0016 — Collection reads Card Catalog, for queries only

- Status: accepted
- Date: 2026-09-23

## Context

Issue #54 adds name search to the Collection page ("do I own card X"), alongside the
same search already added to Catalog. Collection stores only `(CardKey, Finish,
Language) -> quantity` — no card names — so a name filter over the collection needs
Catalog's `name` column.

`docs/dev/architecture.md` states "Card Catalog and Collection are upstream: they
depend on no other context." Card Catalog never depends on Collection, so a
Collection → Card Catalog read is acyclic, but it still reverses that stated
invariant and needs its own decision, not a quiet exception.

## Considered options

- **Host the search in Insights** — Insights already reads both Collection and
  Catalog for set completion, so a `SearchCollectionCards` query there would need
  no new cross-BC edge. Rejected: it would duplicate `CollectionCard`/`CollectionCopy`
  and the `Finish`/`Language` enums in a second contract, duplicate collection's
  filing-order policy, and force the client to call a different method depending on
  whether a filter is active — two ways to list the same data.
- **Filter client-side** — fetch the full collection and Catalog's names once, filter
  in the browser. Rejected: the collection is already paginated server-side because
  ~5.2k printings is too much to hand the client at once (issue #54's own premise);
  fetching all of it to filter client-side undoes that.
- **Collection reads Card Catalog, queries only** — add a narrow read port to
  Collection's `list_cards` query, served by `card_catalog/driver/gleam/catalog_api`
  the same way Insights already reads both contexts. One method, one ordering, no
  duplicated shape.

## Decision

Collection may depend on Card Catalog through `card_catalog/driver/gleam/catalog_api`,
**for queries only**. Commands (`import_collection`, `add_cards`, `remove_cards`) may
never depend on Card Catalog: the collection must stay usable — importable, addable to
— before the first catalog sync and after a catalog wipe. The unfiltered
`ListCollectionCards` call and the set-code filter never touch Card Catalog either;
only a name filter does, since only that needs Catalog's `name` column. A card the
catalog doesn't know never matches a name filter (same "enrichment may be absent"
rule Inventory Planning's rule cascade already follows), but still matches on its own
set code.

`server/test/lint.gleam`'s `allowed_cross_bc` gains `#(Collection, CardCatalog)`, and
the diagram and "upstream" sentence in `docs/dev/architecture.md` are updated to say
Card Catalog is the only context with no dependencies.

## Consequences

- Card Catalog remains the one context every other context can safely depend on
  (still no dependency of its own). Collection is no longer a second dependency-free
  root — Insights and Inventory Planning already depended on it, so this does not add
  a new context to anyone's transitive closure.
- The queries-only line is enforced by review, not by the lint rule (which only
  checks context pairs, not layers within a pair) — a future PR adding a Catalog
  read to a Collection *command* is a violation of this ADR even though the linter
  would accept it.
- A name search during a catalog refresh (`DELETE` + reinsert, per
  `card_catalog/AGENTS.md`) can return partial results for the window the table is
  empty or half-reloaded — the same staleness a Catalog-page search already accepts
  mid-refresh, now shared by Collection's name search too.
- If a second Collection query ever wants a Card Catalog read, it reuses this
  dependency rather than reopening the question; a Collection *command* wanting one
  is a new decision, not covered by this ADR.

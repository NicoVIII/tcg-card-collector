# 0007 — `{set_family}` location-template placeholder

- Status: accepted
- Date: 2026-07-12

## Context

Scryfall models a set's tokens, promos, art series, and similar extras as their
own sets (`tgrn`, `pgrn`, … for `grn`), each linked to its parent by
`parent_set_code`. A `Binder {set_code}` rule therefore scatters those cards
into separate `tXXX`/`pXXX` binders instead of keeping them with the parent
set's binder. Collectors overwhelmingly want the whole *set family* — the parent
set plus all its child sets — physically together, with the extras behind the
main set.

We needed a way to express "one binder per set family" that (a) merges the
buckets, (b) orders families against each other the way `{set_code}` orders
sets, and (c) orders cards within a family binder root-first.

## Considered options

- **New `{set_family}` placeholder** (chosen) — a template attribute that renders
  the family-root set code. `{set_code}` keeps its exact current meaning; users
  opt into family grouping by choosing the new token. Requires syncing
  `parent_set_code` from Scryfall and resolving families in the domain.
- **Per-set fixed rules** (`set_code in (grn, tgrn)` → one fixed binder) — no
  schema change, but explodes into one hand-maintained rule per set, gives no
  automatic back-of-binder ordering for the extras, and breaks the moment a new
  child set appears.
- **Change `{set_code}` semantics to fold children onto the parent** — no new
  token to learn, but a silent behaviour change to existing rules, and it
  removes the ability to bucket strictly by literal set code.
- **An explicit per-rule sort key** — orders cards but cannot *merge* the
  distinct `tXXX`/`grn` buckets into one, which is the actual requirement.

## Decision

Add a `{set_family}` placeholder to the LocationTarget DSL. It renders the
family-root set code, resolved by walking `parent_set_code` links transitively
(with a depth cap that doubles as a cycle guard). `{set_code}` is left
untouched. Family buckets sort against sibling buckets on the root's release
date then root code (identical to `{set_code}` buckets). Within a family binder,
root-set cards sort before child-set cards; children order by their own release
date then set code; the rule's sort keys break ties within each group. The
root-first rule holds even when a child set released earlier than its parent —
this is intentional, not a bug.

Sync `parent_set_code` (nullable) into `catalog_sets`, expose it alongside
release date via the catalog's set-metadata query, and have the projection
handler fetch parent metadata transitively (unowned parents surface only after
following child links).

## Consequences

- A new catalog column and a set re-sync backfill (migration resets
  `last_upstream_updated_at`). The set-metadata read now carries the parent link,
  and its insert binds 7 params/row, so the chunk size dropped to stay under
  SQLite's 999-parameter cap.
- The projection handler makes up to one extra set-metadata round trip to reach
  unowned parent sets; bounded by a round cap and terminated early by a
  cycle-safe `already-fetched` filter.
- Users get a single opt-in token with no change to existing `{set_code}` rules.
- Ordering carries a deliberate quirk (root-first beats an earlier-released
  child) that must be preserved; it is commented at the comparison site.

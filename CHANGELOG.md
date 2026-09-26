# Changelog

What changed in each release, for someone deciding whether and how to upgrade a
self-hosted instance. Internals, refactors, and dependency bumps are not listed here —
see the commit history for those.

Newest first. `## Unreleased` collects entries as changes land; cutting a release
renames it to `## vX.Y.Z — YYYY-MM-DD` (see [docs/dev/development.md](docs/dev/development.md)
§ Versioning & Releases for the full procedure).

Each release section uses only the subheadings it needs:

- `### Added` / `### Changed` / `### Fixed` — user-visible behaviour, in plain language.
- `### Upgrading` — anything an upgrade requires, and whether the release can lose
  collection or inventory data (see [README.md](README.md) § Data preservation).

## Unreleased

### Added

- Placement shows each row's section — the sort-key categories it falls under (e.g. `Color R ·
  Type Artifact · CMC 1–3`) — as a divider before the row, so a first-pass inventory gives the
  user something physical to go on even before any neighbouring card is placed.
- Placement rows get an "Up to here" button, marking everything from the top of the location
  through that row as placed in one action — the middle ground between ticking one card and
  marking a whole location. Undoable as a single batch, like "Mark all placed".

## v0.2.0 — 2026-09-26

### Added

- Inventory rules can negate `set_code`, `color_identity`, `type`, and `finish` clauses with
  `!=` (e.g. `finish != foil`).
- Inventory rules can match printed language (`language = de`, `language in (de, fr)`,
  `language != en`) and sort by it (`language`, English first then by code), so non-English
  copies can be routed to their own binder or box.
- Inventory rules can match a card's supertype (`supertype = basic`, `supertype in (basic,
  legendary)`, `supertype != basic`), so `type = land and supertype = basic` routes the 12 basic
  lands to their own box separately from every other land.
- Inventory rules can match token cards (`token = yes`, `token = no`, `token != yes`) by Scryfall's
  `layout`, so tokens can be routed to their own box or binder, or excluded from a rule, while
  staying in the collection — `type` and `supertype` still sort them by creature or artifact.
- Everything hand-made in the app — the collection, set targets, location rules, bulk spec,
  and placed ledger — can be exported to a versioned JSON file ("Back up & restore…" on the
  Collection page, `GET /api/export`, or Skir `ExportData`), fulfilling v0.2.0's data
  portability promise. An exported file imports into any release of the same major version
  or the next one; a release dropping an older format version says so under `### Upgrading`.
- The exported file can be read back in from the same Backup page (a preview shows, per
  section, how many entries will import and names any entry it can't, and warns if the
  ledger it carries would exceed the collection it carries before you confirm),
  `POST /api/import-data` (or `/api/import-data/preview` to check first), or Skir `ImportData` /
  `PreviewImport`. The collection always replaces in full; every other section replaces only
  when the file has it, and is left untouched otherwise. A placed copy the restored collection
  doesn't own enough of is pruned from the ledger right after import, the same as any other
  collection-shrinking write. The round trip is byte-for-byte exact, including every finish
  and the zhs/zht split.

### Changed

- The deckstats CSV importer, its "Import / reset collection…" page, and `POST /api/import` /
  Skir `ImportCollection` are removed — a collection-only import is a lossy, unverified path
  now that the own-format restore above covers it. Restore a collection from "Back up &
  restore…" instead.

### Fixed

- `type = land` and `{type}` place a double-faced or transform card by its front face only, not
  whichever face happens to say "land" (CR 712.8a). Existing modal-DFC and transform-to-land cards
  move out of the Land location the next time a projection runs.

### Upgrading

- **Refresh the catalog after upgrading, and let it finish.** `token` clauses read a catalog
  field that only a full reload fills in, and the first Refresh after the upgrade does that
  reload (a few minutes). Until it completes, `token = yes` and `token = no` match no card,
  and those cards fall through to later rules without an error. The Catalog page loses track
  of a running refresh if you reload or leave it; the reload is done once the page shows
  "Last refresh: succeeded" again.

## v0.1.0 — 2026-09-23

First tagged release. See [README.md](https://github.com/NicoVIII/tcg-card-collector/blob/v0.1.0/README.md) § What works today for what the
service does.

### Added

- Search the Catalog page by card name (case-insensitive substring) and set code.
- Search the Collection page the same way, and list the collection over REST
  (`GET /api/collection/cards`).
- Search the Inventory page's projection by card name and set code, to answer
  "where is card X" without opening every location.

### Changed

- The Inventory page's projection now collapses to a list of locations (name +
  card count); opening one shows its cards, paged and scrollable, instead of every
  location's full table rendering on one page.

### Upgrading

There is no earlier tagged release to upgrade from, but anyone running a `main` image
built before this tag needs to take the same steps, because two migrations already
merged to `main` (`0016_collection_copy_key.sql`, `0017_placed_cards_copy_key.sql`)
rebuild `collection` and `placed_cards` around finish and language:

- **Back up the database file first.** Both migrations do a `DROP TABLE` mid-rebuild;
  no data is lost by the migration itself, but there is no going back without a copy.
- **Every existing owned copy is backfilled as `nonfoil`/`en`.** The model has no
  "unknown" finish or language, so until re-imported, all owned copies read as English
  nonfoil — even ones that are actually foil or in another language.
- **Re-import the collection** (a deckstats export, now read with its `is_foil`/
  `language` columns) to recover the real finish/language split.
- **Re-tick placements for copies that turn out to be foil or another language.** A
  pre-migration tick is attributed to the `nonfoil`/`en` kind; once a re-import reveals
  the real finish/language, that copy shows as unplaced again under its new identity,
  while the old tick stays on the (now probably wrong) `nonfoil`/`en` entry.

From v0.1.0 on, an upgrade never loses collection or inventory data (see README §
Data preservation) — this is the one release where that promise does not yet hold.

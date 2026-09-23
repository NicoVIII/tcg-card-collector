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

- Search the Catalog page by card name (case-insensitive substring) and set code.
- Search the Collection page the same way, and list the collection over REST
  (`GET /api/collection/cards`).

## v0.1.0 — unreleased

First tagged release. See [README.md](README.md) § What works today for what the
service does.

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

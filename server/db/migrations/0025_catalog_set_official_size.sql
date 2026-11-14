-- migrate:up
-- The official set size is resolved at sync from Scryfall printed_size, MTGJSON
-- baseSetSize, or a token set's card_count (ADR 0025); the source is stored
-- with it. SQLite can't add a cross-column CHECK with ALTER, so the table is
-- rebuilt. catalog_sets is reloaded from upstream on every sets import, so
-- rows start with no size, and clearing the sync record forces that reload on
-- the next boot or Refresh (card_catalog/AGENTS.md, #114).
CREATE TABLE catalog_sets_new (
  set_code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  released_at TEXT NOT NULL DEFAULT '',
  card_count INTEGER NOT NULL DEFAULT 0,
  icon_svg_uri TEXT NOT NULL DEFAULT '',
  official_size INTEGER CHECK (official_size IS NULL OR official_size > 0),
  official_size_source TEXT CHECK (
    official_size_source IS NULL
    OR official_size_source IN ('printed_size', 'base_set_size', 'token_card_count')
  ),
  parent_set_code TEXT,
  CHECK ((official_size IS NULL) = (official_size_source IS NULL))
) STRICT;
INSERT INTO catalog_sets_new (set_code, name, released_at, card_count, icon_svg_uri, parent_set_code)
  SELECT set_code, name, released_at, card_count, icon_svg_uri, parent_set_code FROM catalog_sets;
DROP TABLE catalog_sets;
ALTER TABLE catalog_sets_new RENAME TO catalog_sets;
DELETE FROM catalog_sync_metadata;
-- migrate:down
CREATE TABLE catalog_sets_old (
  set_code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  released_at TEXT NOT NULL DEFAULT '',
  card_count INTEGER NOT NULL DEFAULT 0,
  icon_svg_uri TEXT NOT NULL DEFAULT '',
  printed_size INTEGER,
  parent_set_code TEXT
) STRICT;
INSERT INTO catalog_sets_old (set_code, name, released_at, card_count, icon_svg_uri, printed_size, parent_set_code)
  SELECT set_code, name, released_at, card_count, icon_svg_uri,
    CASE WHEN official_size_source = 'printed_size' THEN official_size END,
    parent_set_code
  FROM catalog_sets;
DROP TABLE catalog_sets;
ALTER TABLE catalog_sets_old RENAME TO catalog_sets;

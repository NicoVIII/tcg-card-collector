-- migrate:up

-- Convert every table to STRICT. The database is a boundary: other writers
-- (sqlite3 CLI bulk import, manual surgery) bypass the app's types, and
-- default type affinity would silently store e.g. text in INTEGER columns.
-- SQLite cannot ALTER a table to STRICT, so each table is recreated and its
-- rows copied; schemas are otherwise identical (ALTER-accumulated columns
-- flattened).

CREATE TABLE catalog_cards_strict (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  rarity TEXT NOT NULL,
  image_uri TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  oracle_id TEXT NOT NULL DEFAULT '',
  color_identity TEXT NOT NULL DEFAULT '',
  type_line TEXT NOT NULL DEFAULT '',
  released_at TEXT NOT NULL DEFAULT ''
) STRICT;
INSERT INTO catalog_cards_strict (id, name, set_code, collector_number, rarity, image_uri, created_at, updated_at, oracle_id, color_identity, type_line, released_at)
  SELECT id, name, set_code, collector_number, rarity, image_uri, created_at, updated_at, oracle_id, color_identity, type_line, released_at FROM catalog_cards;
DROP TABLE catalog_cards;
ALTER TABLE catalog_cards_strict RENAME TO catalog_cards;
CREATE INDEX idx_catalog_cards_name ON catalog_cards(name);
CREATE INDEX idx_catalog_cards_set_code ON catalog_cards(set_code);
CREATE INDEX idx_catalog_cards_key ON catalog_cards(set_code, collector_number);

CREATE TABLE catalog_sets_strict (
  set_code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  released_at TEXT NOT NULL DEFAULT '',
  card_count INTEGER NOT NULL DEFAULT 0,
  icon_svg_uri TEXT NOT NULL DEFAULT '',
  printed_size INTEGER,
  parent_set_code TEXT
) STRICT;
INSERT INTO catalog_sets_strict (set_code, name, released_at, card_count, icon_svg_uri, printed_size, parent_set_code)
  SELECT set_code, name, released_at, card_count, icon_svg_uri, printed_size, parent_set_code FROM catalog_sets;
DROP TABLE catalog_sets;
ALTER TABLE catalog_sets_strict RENAME TO catalog_sets;

CREATE TABLE catalog_sync_metadata_strict (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  last_probe_at TEXT,
  last_upstream_updated_at TEXT,
  last_refresh_status TEXT CHECK (
    last_refresh_status IS NULL
    OR last_refresh_status IN ('succeeded', 'failed', 'skipped')
  ),
  last_error_message TEXT,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO catalog_sync_metadata_strict (id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at)
  SELECT id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at FROM catalog_sync_metadata;
DROP TABLE catalog_sync_metadata;
ALTER TABLE catalog_sync_metadata_strict RENAME TO catalog_sync_metadata;

CREATE TABLE collection_strict (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number)
) STRICT;
INSERT INTO collection_strict (set_code, collector_number, quantity)
  SELECT set_code, collector_number, quantity FROM collection;
DROP TABLE collection;
ALTER TABLE collection_strict RENAME TO collection;

CREATE TABLE placed_cards_strict (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  location TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, location)
) STRICT;
INSERT INTO placed_cards_strict (set_code, collector_number, location, quantity)
  SELECT set_code, collector_number, location, quantity FROM placed_cards;
DROP TABLE placed_cards;
ALTER TABLE placed_cards_strict RENAME TO placed_cards;

CREATE TABLE inventory_rules_strict (
  id TEXT PRIMARY KEY,
  location_name TEXT NOT NULL,
  expression TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  position INTEGER NOT NULL DEFAULT 0,
  selector TEXT NOT NULL DEFAULT 'all',
  sort_keys TEXT NOT NULL DEFAULT ''
) STRICT;
INSERT INTO inventory_rules_strict (id, location_name, expression, created_at, updated_at, position, selector, sort_keys)
  SELECT id, location_name, expression, created_at, updated_at, position, selector, sort_keys FROM inventory_rules;
DROP TABLE inventory_rules;
ALTER TABLE inventory_rules_strict RENAME TO inventory_rules;
CREATE INDEX idx_inventory_rules_location_name ON inventory_rules(location_name);

CREATE TABLE inventory_bulk_spec_strict (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  location_name TEXT NOT NULL,
  sort_keys TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO inventory_bulk_spec_strict (id, location_name, sort_keys, updated_at)
  SELECT id, location_name, sort_keys, updated_at FROM inventory_bulk_spec;
DROP TABLE inventory_bulk_spec;
ALTER TABLE inventory_bulk_spec_strict RENAME TO inventory_bulk_spec;

CREATE TABLE app_settings_strict (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  default_sort TEXT NOT NULL,
  default_grouping TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO app_settings_strict (id, default_sort, default_grouping, updated_at)
  SELECT id, default_sort, default_grouping, updated_at FROM app_settings;
DROP TABLE app_settings;
ALTER TABLE app_settings_strict RENAME TO app_settings;

CREATE TABLE target_sets_strict (
  set_code TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO target_sets_strict (set_code, created_at)
  SELECT set_code, created_at FROM target_sets;
DROP TABLE target_sets;
ALTER TABLE target_sets_strict RENAME TO target_sets;

-- migrate:down

CREATE TABLE catalog_cards_loose (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  rarity TEXT NOT NULL,
  image_uri TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  oracle_id TEXT NOT NULL DEFAULT '',
  color_identity TEXT NOT NULL DEFAULT '',
  type_line TEXT NOT NULL DEFAULT '',
  released_at TEXT NOT NULL DEFAULT ''
);
INSERT INTO catalog_cards_loose (id, name, set_code, collector_number, rarity, image_uri, created_at, updated_at, oracle_id, color_identity, type_line, released_at)
  SELECT id, name, set_code, collector_number, rarity, image_uri, created_at, updated_at, oracle_id, color_identity, type_line, released_at FROM catalog_cards;
DROP TABLE catalog_cards;
ALTER TABLE catalog_cards_loose RENAME TO catalog_cards;
CREATE INDEX idx_catalog_cards_name ON catalog_cards(name);
CREATE INDEX idx_catalog_cards_set_code ON catalog_cards(set_code);
CREATE INDEX idx_catalog_cards_key ON catalog_cards(set_code, collector_number);

CREATE TABLE catalog_sets_loose (
  set_code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  released_at TEXT NOT NULL DEFAULT '',
  card_count INTEGER NOT NULL DEFAULT 0,
  icon_svg_uri TEXT NOT NULL DEFAULT '',
  printed_size INTEGER,
  parent_set_code TEXT
);
INSERT INTO catalog_sets_loose (set_code, name, released_at, card_count, icon_svg_uri, printed_size, parent_set_code)
  SELECT set_code, name, released_at, card_count, icon_svg_uri, printed_size, parent_set_code FROM catalog_sets;
DROP TABLE catalog_sets;
ALTER TABLE catalog_sets_loose RENAME TO catalog_sets;

CREATE TABLE catalog_sync_metadata_loose (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  last_probe_at TEXT,
  last_upstream_updated_at TEXT,
  last_refresh_status TEXT CHECK (
    last_refresh_status IS NULL
    OR last_refresh_status IN ('succeeded', 'failed', 'skipped')
  ),
  last_error_message TEXT,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO catalog_sync_metadata_loose (id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at)
  SELECT id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at FROM catalog_sync_metadata;
DROP TABLE catalog_sync_metadata;
ALTER TABLE catalog_sync_metadata_loose RENAME TO catalog_sync_metadata;

CREATE TABLE collection_loose (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number)
);
INSERT INTO collection_loose (set_code, collector_number, quantity)
  SELECT set_code, collector_number, quantity FROM collection;
DROP TABLE collection;
ALTER TABLE collection_loose RENAME TO collection;

CREATE TABLE placed_cards_loose (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  location TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, location)
);
INSERT INTO placed_cards_loose (set_code, collector_number, location, quantity)
  SELECT set_code, collector_number, location, quantity FROM placed_cards;
DROP TABLE placed_cards;
ALTER TABLE placed_cards_loose RENAME TO placed_cards;

CREATE TABLE inventory_rules_loose (
  id TEXT PRIMARY KEY,
  location_name TEXT NOT NULL,
  expression TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  position INTEGER NOT NULL DEFAULT 0,
  selector TEXT NOT NULL DEFAULT 'all',
  sort_keys TEXT NOT NULL DEFAULT ''
);
INSERT INTO inventory_rules_loose (id, location_name, expression, created_at, updated_at, position, selector, sort_keys)
  SELECT id, location_name, expression, created_at, updated_at, position, selector, sort_keys FROM inventory_rules;
DROP TABLE inventory_rules;
ALTER TABLE inventory_rules_loose RENAME TO inventory_rules;
CREATE INDEX idx_inventory_rules_location_name ON inventory_rules(location_name);

CREATE TABLE inventory_bulk_spec_loose (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  location_name TEXT NOT NULL,
  sort_keys TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO inventory_bulk_spec_loose (id, location_name, sort_keys, updated_at)
  SELECT id, location_name, sort_keys, updated_at FROM inventory_bulk_spec;
DROP TABLE inventory_bulk_spec;
ALTER TABLE inventory_bulk_spec_loose RENAME TO inventory_bulk_spec;

CREATE TABLE app_settings_loose (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  default_sort TEXT NOT NULL,
  default_grouping TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO app_settings_loose (id, default_sort, default_grouping, updated_at)
  SELECT id, default_sort, default_grouping, updated_at FROM app_settings;
DROP TABLE app_settings;
ALTER TABLE app_settings_loose RENAME TO app_settings;

CREATE TABLE target_sets_loose (
  set_code TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO target_sets_loose (set_code, created_at)
  SELECT set_code, created_at FROM target_sets;
DROP TABLE target_sets;
ALTER TABLE target_sets_loose RENAME TO target_sets;

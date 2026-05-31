PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS catalog_cards (
  id TEXT PRIMARY KEY,
  oracle_id TEXT NOT NULL,
  name TEXT NOT NULL,
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  rarity TEXT NOT NULL,
  image_small_uri TEXT NOT NULL,
  image_normal_uri TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_catalog_cards_name
  ON catalog_cards(name);

CREATE INDEX IF NOT EXISTS idx_catalog_cards_set_code
  ON catalog_cards(set_code);

CREATE INDEX IF NOT EXISTS idx_catalog_cards_oracle_id
  ON catalog_cards(oracle_id);

CREATE TABLE IF NOT EXISTS catalog_sync_metadata (
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

CREATE TABLE IF NOT EXISTS inventory_rules (
  id TEXT PRIMARY KEY,
  location_name TEXT NOT NULL,
  expression TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_inventory_rules_location_name
  ON inventory_rules(location_name);

CREATE TABLE IF NOT EXISTS app_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  default_sort TEXT NOT NULL,
  default_grouping TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO app_settings (
  id,
  default_sort,
  default_grouping
) VALUES (
  1,
  'card_name',
  'location_name'
);

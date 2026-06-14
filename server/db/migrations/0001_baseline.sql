-- migrate:up

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS import_runs (
  id TEXT PRIMARY KEY,
  source_name TEXT NOT NULL,
  source_checksum TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'running', 'succeeded', 'failed')),
  started_at TEXT NOT NULL,
  finished_at TEXT,
  error_message TEXT,
  imported_row_count INTEGER NOT NULL DEFAULT 0 CHECK (imported_row_count >= 0),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_import_runs_status ON import_runs(status);
CREATE INDEX IF NOT EXISTS idx_import_runs_started_at ON import_runs(started_at DESC);

CREATE TABLE IF NOT EXISTS collection_snapshot (
  id TEXT PRIMARY KEY,
  import_run_id TEXT NOT NULL REFERENCES import_runs(id) ON DELETE CASCADE,
  row_number INTEGER NOT NULL CHECK (row_number > 0),
  set_code TEXT NOT NULL,
  collector_number TEXT,
  finish TEXT,
  language TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(import_run_id, row_number)
);

CREATE INDEX IF NOT EXISTS idx_collection_snapshot_import_run_id
  ON collection_snapshot(import_run_id);
CREATE INDEX IF NOT EXISTS idx_collection_snapshot_card_lookup
  ON collection_snapshot(set_code, collector_number);

CREATE TABLE IF NOT EXISTS catalog_cards (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  rarity TEXT NOT NULL,
  image_uri TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_catalog_cards_name
  ON catalog_cards(name);

CREATE INDEX IF NOT EXISTS idx_catalog_cards_set_code
  ON catalog_cards(set_code);

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

-- migrate:down

DROP TABLE IF EXISTS app_settings;
DROP TABLE IF EXISTS inventory_rules;
DROP TABLE IF EXISTS catalog_sync_metadata;
DROP TABLE IF EXISTS catalog_cards;
DROP TABLE IF EXISTS collection_snapshot;
DROP TABLE IF EXISTS import_runs;

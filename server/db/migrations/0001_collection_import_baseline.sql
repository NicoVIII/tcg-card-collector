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
  card_name TEXT NOT NULL,
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
  ON collection_snapshot(card_name, set_code, collector_number);

-- migrate:down

DROP TABLE IF EXISTS collection_snapshot;
DROP TABLE IF EXISTS import_runs;

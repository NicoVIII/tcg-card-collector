-- migrate:up

CREATE TABLE collection (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number)
);

CREATE TABLE unplaced_cards (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number)
);

-- Seed the current collection from the latest succeeded snapshot (the only run
-- the old read path ever queried), summing duplicate keys as that read did.
INSERT INTO collection (set_code, collector_number, quantity)
  WITH latest_succeeded AS (
    SELECT id FROM import_runs WHERE status = 'succeeded'
    ORDER BY updated_at DESC, created_at DESC, rowid DESC LIMIT 1
  )
  SELECT s.set_code, s.collector_number, SUM(s.quantity)
  FROM collection_snapshot s JOIN latest_succeeded ls ON s.import_run_id = ls.id
  GROUP BY s.set_code, s.collector_number;

DROP TABLE collection_snapshot;
DROP TABLE import_runs;

-- migrate:down

CREATE TABLE import_runs (
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

CREATE INDEX idx_import_runs_status ON import_runs(status);
CREATE INDEX idx_import_runs_started_at ON import_runs(started_at DESC);

CREATE TABLE collection_snapshot (
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

CREATE INDEX idx_collection_snapshot_import_run_id
  ON collection_snapshot(import_run_id);
CREATE INDEX idx_collection_snapshot_card_lookup
  ON collection_snapshot(set_code, collector_number);

DROP TABLE unplaced_cards;
DROP TABLE collection;

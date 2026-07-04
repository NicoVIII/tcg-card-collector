-- migrate:up

CREATE TABLE IF NOT EXISTS target_sets (
  set_code TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- migrate:down

DROP TABLE IF EXISTS target_sets;

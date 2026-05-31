#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required but not installed"
  exit 1
fi

DB_FILE=$(mktemp /tmp/tcg_storage_smoke.XXXXXX.db)
cleanup() {
  rm -f "$DB_FILE"
}
trap cleanup EXIT

sqlite3 "$DB_FILE" < server/db/migrations/0001_collection_import_baseline.sql

sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = ON;
INSERT INTO import_runs (
  id,
  source_name,
  source_checksum,
  status,
  started_at,
  imported_row_count
) VALUES (
  'run-1',
  'deckstats-export.csv',
  'checksum-1',
  'succeeded',
  '2026-05-31T12:00:00Z',
  2
);

INSERT INTO collection_snapshot (
  id,
  import_run_id,
  row_number,
  card_name,
  set_code,
  collector_number,
  finish,
  language,
  quantity
) VALUES
  (
    'snap-1',
    'run-1',
    1,
    'Lightning Bolt',
    'M11',
    '146',
    'nonfoil',
    'en',
    2
  ),
  (
    'snap-2',
    'run-1',
    2,
    'Counterspell',
    '2XM',
    '49',
    'foil',
    'en',
    1
  );
SQL

import_runs_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM import_runs;")
collection_snapshot_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM collection_snapshot;")

if [ "$import_runs_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 import_run, got $import_runs_count"
  exit 1
fi

if [ "$collection_snapshot_count" != "2" ]; then
  echo "Storage smoke check failed: expected 2 snapshot rows, got $collection_snapshot_count"
  exit 1
fi

echo "Storage smoke checks passed"

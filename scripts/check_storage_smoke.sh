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

for migration in server/db/migrations/*.sql; do
  sqlite3 "$DB_FILE" < "$migration"
done

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

INSERT INTO catalog_cards (
  id,
  oracle_id,
  name,
  set_code,
  collector_number,
  rarity,
  image_small_uri,
  image_normal_uri
) VALUES (
  'card-1',
  'oracle-1',
  'Lightning Bolt',
  'M11',
  '146',
  'common',
  'https://img.example.com/bolt-small.jpg',
  'https://img.example.com/bolt-normal.jpg'
);

INSERT INTO catalog_sync_metadata (
  id,
  last_probe_at,
  last_upstream_updated_at,
  last_refresh_status,
  last_error_message
) VALUES (
  1,
  '2026-05-31T12:00:00Z',
  '2026-05-31T11:00:00Z',
  'succeeded',
  NULL
);

INSERT INTO inventory_rules (
  id,
  location_name,
  expression
) VALUES (
  'rule-1',
  'main-binder',
  'set_code=M11'
);
SQL

import_runs_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM import_runs;")
collection_snapshot_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM collection_snapshot;")
catalog_cards_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM catalog_cards;")
catalog_sync_metadata_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM catalog_sync_metadata;")
inventory_rules_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM inventory_rules;")
app_settings_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM app_settings;")
default_grouping=$(sqlite3 "$DB_FILE" "SELECT default_grouping FROM app_settings WHERE id = 1;")

if [ "$import_runs_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 import_run, got $import_runs_count"
  exit 1
fi

if [ "$collection_snapshot_count" != "2" ]; then
  echo "Storage smoke check failed: expected 2 snapshot rows, got $collection_snapshot_count"
  exit 1
fi

if [ "$catalog_cards_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 catalog card, got $catalog_cards_count"
  exit 1
fi

if [ "$catalog_sync_metadata_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 catalog sync metadata row, got $catalog_sync_metadata_count"
  exit 1
fi

if [ "$inventory_rules_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 inventory rule, got $inventory_rules_count"
  exit 1
fi

if [ "$app_settings_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 app settings row, got $app_settings_count"
  exit 1
fi

if [ "$default_grouping" != "location_name" ]; then
  echo "Storage smoke check failed: expected default grouping location_name, got $default_grouping"
  exit 1
fi

echo "Storage smoke checks passed"

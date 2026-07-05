#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required but not installed"
  exit 1
fi

if ! command -v dbmate >/dev/null 2>&1; then
  echo "dbmate is required but not installed"
  echo "Run: ./scripts/install_dbmate.sh"
  exit 1
fi

DB_FILE=$(mktemp /tmp/tcg_storage_smoke.XXXXXX.db)
cleanup() {
  rm -f "$DB_FILE"
}
trap cleanup EXIT

TCG_DB_FILE="$DB_FILE" sh ./scripts/dbmate_up.sh >/dev/null

sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = ON;
INSERT INTO collection (
  set_code,
  collector_number,
  quantity
) VALUES
  ('M11', '146', 2),
  ('2XM', '49', 1);

INSERT INTO unplaced_cards (
  set_code,
  collector_number,
  quantity
) VALUES
  ('2XM', '49', 1);

INSERT INTO catalog_cards (
  id,
  name,
  set_code,
  collector_number,
  rarity,
  image_uri
) VALUES (
  'card-1',
  'Lightning Bolt',
  'M11',
  '146',
  'common',
  'https://img.example.com/bolt.jpg'
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

collection_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM collection;")
unplaced_cards_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM unplaced_cards;")
catalog_cards_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM catalog_cards;")
catalog_sync_metadata_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM catalog_sync_metadata;")
inventory_rules_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM inventory_rules;")
app_settings_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM app_settings;")
default_grouping=$(sqlite3 "$DB_FILE" "SELECT default_grouping FROM app_settings WHERE id = 1;")

if [ "$collection_count" != "2" ]; then
  echo "Storage smoke check failed: expected 2 collection rows, got $collection_count"
  exit 1
fi

if [ "$unplaced_cards_count" != "1" ]; then
  echo "Storage smoke check failed: expected 1 unplaced_cards row, got $unplaced_cards_count"
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

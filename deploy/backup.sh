#!/usr/bin/env sh
set -eu

DB_PATH="${DATABASE_PATH:-./data/tcg_card_collector.db}"
OUT_DIR="${BACKUP_DIR:-./backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$OUT_DIR"

if [ -f "$DB_PATH" ]; then
  cp "$DB_PATH" "$OUT_DIR/tcg_card_collector-$STAMP.db"
  echo "Backup written: $OUT_DIR/tcg_card_collector-$STAMP.db"
else
  echo "Database file not found at $DB_PATH"
  exit 1
fi

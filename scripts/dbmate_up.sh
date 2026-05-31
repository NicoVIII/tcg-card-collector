#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v dbmate >/dev/null 2>&1; then
  echo "dbmate is required but not installed"
  echo "Run: ./scripts/install_dbmate.sh"
  exit 1
fi

DB_FILE=${TCG_DB_FILE:-tcg-card-collector.db}
DATABASE_URL="sqlite:${DB_FILE}" \
  dbmate --migrations-dir server/db/migrations --no-dump-schema up

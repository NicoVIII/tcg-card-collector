#!/bin/sh
set -eu

# Create the database file if it doesn't exist yet
if [ ! -f "$TCG_DB_FILE" ]; then
  touch "$TCG_DB_FILE"
fi

# Migrate before boot: the app assumes the schema exists and does not run
# migrations itself.
DATABASE_URL="sqlite:${TCG_DB_FILE}" \
  dbmate --migrations-dir /app/db/migrations --no-dump-schema up

exec /app/entrypoint.sh "$@"

#!/bin/sh
set -eu

# Migrate before boot: the app assumes the schema exists and does not run
# migrations itself.
DATABASE_URL="sqlite:${TCG_DB_FILE}" \
  dbmate --migrations-dir /app/db/migrations --no-dump-schema up

exec /app/entrypoint.sh "$@"

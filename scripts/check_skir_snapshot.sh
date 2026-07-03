#!/usr/bin/env sh
# Verify the committed skir snapshot is up to date.
#
# `skir snapshot --ci` prints a drift warning but still exits 0 (verified with
# skir@1.2.19), so CI cannot fail on contract drift on its own -- unlike
# `format --ci`, which does propagate a non-zero exit. We run it, echo its
# output, and fail ourselves if the drift warning appears. See issue #31.
set -eu

cd "$(dirname "$0")/.."

version="${1:?usage: check_skir_snapshot.sh <skir-version>}"

if command -v bunx >/dev/null 2>&1; then
  runner="bunx"
else
  runner="npx"
fi

status=0
output=$("$runner" "skir@${version}" snapshot --ci 2>&1) || status=$?
printf '%s\n' "$output"

if [ "$status" -ne 0 ]; then
  exit "$status"
fi

if printf '%s\n' "$output" | grep -q "have changed since the last snapshot"; then
  echo "Error: skir snapshot is out of date. Run 'just skir-snapshot' and commit skir-snapshot.json." >&2
  exit 1
fi

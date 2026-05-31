#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if [ ! -d skir-src ]; then
  echo "Missing skir-src directory"
  exit 1
fi

if [ ! -f skir-snapshot.txt ]; then
  echo "Missing skir-snapshot.txt"
  exit 1
fi

ACTUAL=$(mktemp /tmp/skir_snapshot_actual.XXXXXX)
cleanup() {
  rm -f "$ACTUAL"
}
trap cleanup EXIT

find skir-src -type f -name "*.skir" | sort | while IFS= read -r file; do
  sha256sum "$file"
done > "$ACTUAL"

if ! diff -u skir-snapshot.txt "$ACTUAL"; then
  echo "Contract snapshot mismatch. Update skir-snapshot.txt when contracts change."
  exit 1
fi

echo "Contract snapshot check passed"

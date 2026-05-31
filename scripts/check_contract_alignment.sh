#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

client_methods=$(mktemp /tmp/client_skir_methods.XXXXXX)
contract_methods=$(mktemp /tmp/contract_skir_methods.XXXXXX)
cleanup() {
  rm -f "$client_methods" "$contract_methods"
}
trap cleanup EXIT

if [ ! -d skir-src ]; then
  echo "Missing skir-src contract directory"
  exit 1
fi

if [ ! -d client-web/src/data ]; then
  echo "Missing frontend data directory"
  exit 1
fi

grep -Rho '^method[[:space:]]\+[A-Za-z0-9_]\+' skir-src \
  | awk '{print $2}' \
  | sort -u > "$contract_methods"

find client-web/src/data -type f -name "request.ts" \
  | sort \
  | while IFS= read -r file; do
      awk '
        /invokeRemote\([[:space:]]*[A-Za-z0-9_]+/ {
          line = $0
          sub(/.*invokeRemote\([[:space:]]*/, "", line)
          sub(/,.*/, "", line)
          gsub(/[[:space:]]/, "", line)
          if (line != "") print line
          next
        }
        /invokeRemote\(/ {
          capture = 1
          next
        }
        capture == 1 {
          line = $0
          gsub(/[[:space:]]/, "", line)
          if (line == "") next
          sub(/,.*/, "", line)
          if (line != "") print line
          capture = 0
        }
      ' "$file"
    done \
  | sort -u > "$client_methods"

missing=0
while IFS= read -r method; do
  if [ -n "$method" ] && ! grep -Fxq "$method" "$contract_methods"; then
    echo "Missing Skir contract method used by frontend: $method"
    missing=1
  fi
done < "$client_methods"

if [ "$missing" -ne 0 ]; then
  echo "Skir contract alignment check failed"
  exit 1
fi

echo "Skir contract alignment check passed"

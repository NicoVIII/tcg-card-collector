#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if [ -f client-web/package.json ]; then
  echo "Frontend scaffold present: client-web/package.json"
else
  echo "Missing frontend scaffold"
  exit 1
fi

if [ -f client-web/src/index.tsx ]; then
  echo "Frontend entrypoint scaffold present"
else
  echo "Missing frontend entrypoint scaffold"
  exit 1
fi

echo "Frontend scaffold checks passed"

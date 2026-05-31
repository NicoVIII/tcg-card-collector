#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v bunx >/dev/null 2>&1; then
  echo "bunx is required but not installed"
  exit 1
fi

if [ ! -f skir.yml ]; then
  echo "Missing skir.yml"
  exit 1
fi

if [ ! -f skir-snapshot.json ]; then
  echo "Missing skir-snapshot.json"
  echo "Run: bunx --bun skir snapshot --root $(pwd)"
  exit 1
fi

bunx --bun skir snapshot --ci --root "$(pwd)"

echo "Contract snapshot check passed"

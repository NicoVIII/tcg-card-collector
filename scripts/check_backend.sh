#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v gleam >/dev/null 2>&1; then
  echo "gleam is required but not installed"
  exit 1
fi

echo "==> backend: format"
(
  cd server
  gleam format --check src test
)

echo "==> backend: typecheck"
(
  cd server
  gleam check
)

echo "==> backend: unit tests"
(
  cd server
  gleam test
)

echo "==> backend: storage smoke"
./scripts/check_storage_smoke.sh

echo "==> backend: contract snapshot"
./scripts/check_contract_snapshot.sh

echo "==> backend: architecture lint"
./server/linting/check_architecture.sh

echo "Backend quality checks passed"

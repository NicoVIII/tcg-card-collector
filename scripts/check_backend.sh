#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v gleam >/dev/null 2>&1; then
  echo "gleam is required but not installed"
  exit 1
fi

format_inputs() {
  find server/src server/test \
    -type f \
    -name '*.gleam' \
    ! -path 'server/src/driver/skirout/*'
}

echo "==> backend: format"
format_inputs | xargs gleam format --check

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

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

echo "==> backend fast: format"
format_inputs | xargs gleam format --check

echo "==> backend fast: typecheck"
(
  cd server
  gleam check
)

echo "==> backend fast: architecture lint"
./server/linting/check_architecture.sh

echo "Backend fast checks passed"

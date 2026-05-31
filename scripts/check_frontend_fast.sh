#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v bun >/dev/null 2>&1; then
  echo "bun is required but not installed"
  exit 1
fi

echo "==> frontend fast: install deps"
(
  cd client-web
  if [ -f bun.lock ]; then
    bun install --frozen-lockfile
  else
    bun install
  fi
)

echo "==> frontend fast: quality"
(
  cd client-web

  find src \
    -type f \
    \( -name '*.ts' -o -name '*.tsx' \) \
    ! -path 'src/data/skirout/*' \
    | xargs bunx --bun oxfmt --check

  bun run lint
  bun run typecheck
)

echo "Frontend fast checks passed"

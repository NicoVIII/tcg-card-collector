#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required but not installed"
  exit 1
fi

echo "==> frontend: install deps"
(
  cd client-web
  if [ -f package-lock.json ]; then
    npm ci
  else
    npm install
  fi
)

echo "==> frontend: quality gates"
(
  cd client-web
  npm run check
)

echo "Frontend quality checks passed"

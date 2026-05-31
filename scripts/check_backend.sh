#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if [ -f server/gleam.toml ]; then
  echo "Backend scaffold present: server/gleam.toml"
else
  echo "Missing backend scaffold"
  exit 1
fi

if [ -f server/src/tcg_card_collector.gleam ]; then
  echo "Backend entrypoint scaffold present"
else
  echo "Missing backend entrypoint scaffold"
  exit 1
fi

echo "Backend scaffold checks passed"

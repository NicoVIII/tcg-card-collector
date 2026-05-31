#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

./scripts/check_backend.sh
./scripts/check_frontend.sh

echo "All scaffold checks passed"

#!/usr/bin/env sh
set -eu

if command -v dbmate >/dev/null 2>&1; then
  exit 0
fi

INSTALL_PATH=${1:-/usr/local/bin/dbmate}
TMP_PATH=$(mktemp /tmp/dbmate.XXXXXX)
cleanup() {
  rm -f "$TMP_PATH"
}
trap cleanup EXIT

curl -fsSL -o "$TMP_PATH" \
  "https://github.com/amacneil/dbmate/releases/latest/download/dbmate-linux-amd64"
chmod +x "$TMP_PATH"

if [ -w "$(dirname "$INSTALL_PATH")" ]; then
  mv "$TMP_PATH" "$INSTALL_PATH"
else
  sudo mv "$TMP_PATH" "$INSTALL_PATH"
fi

"$INSTALL_PATH" --version >/dev/null

#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

server_routes=$(mktemp /tmp/server_routes.XXXXXX)
client_routes=$(mktemp /tmp/client_routes.XXXXXX)
cleanup() {
  rm -f "$server_routes" "$client_routes"
}
trap cleanup EXIT

if [ ! -f server/src/driver/http/router.gleam ]; then
  echo "Missing server HTTP router definition"
  exit 1
fi

if [ ! -d client-web/src/data ]; then
  echo "Missing frontend data layer directory"
  exit 1
fi

sed -n 's/.*\("\/api\/[^\"]*"\).*/\1/p' server/src/driver/http/router.gleam \
  | tr -d '"' \
  | sort -u > "$server_routes"

find client-web/src/data -type f -name "request.ts" \
  | sort \
  | while IFS= read -r file; do
      sed -n 's/.*\("\/api\/[^\"]*"\).*/\1/p' "$file" \
        | tr -d '"' \
        | sed 's/[?].*$//' \
        | sort -u
    done \
  | sort -u > "$client_routes"

missing=0
while IFS= read -r route; do
  if [ -n "$route" ] && ! grep -Fxq "$route" "$server_routes"; then
    echo "Missing server route for frontend endpoint: $route"
    missing=1
  fi
done < "$client_routes"

if [ "$missing" -ne 0 ]; then
  echo "Contract alignment check failed"
  exit 1
fi

echo "Contract alignment check passed"

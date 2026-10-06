#!/usr/bin/env sh
# Run a published release image and check it reports the bare version. A
# release image built with the wrong APP_CHANNEL would report
# X.Y.Z-dev+<sha>, which is what this guards against. Pulls first so it
# checks what GHCR serves, not a stale local copy.
set -eu

version="${1:?usage: verify_release_image.sh <version, e.g. 0.3.0>}"
image="ghcr.io/nicoviii/tcg-card-collector:${version}"
name="release-check-${version}"
port=18080
expected="{\"version\":\"${version}\"}"

docker run -d --rm --pull always --name "$name" -p "127.0.0.1:${port}:8080" "$image" >/dev/null
trap 'docker stop "$name" >/dev/null' EXIT

attempts=60
while ! actual=$(curl -fsS "http://127.0.0.1:${port}/api/version" 2>/dev/null); do
  attempts=$((attempts - 1))
  if [ "$attempts" -eq 0 ]; then
    echo "Error: ${image} did not answer /api/version within 60s." >&2
    exit 1
  fi
  sleep 1
done

if [ "$actual" != "$expected" ]; then
  echo "Error: ${image} reports ${actual}, expected ${expected}." >&2
  exit 1
fi

echo "${image} reports ${actual}."

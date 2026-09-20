#!/usr/bin/env sh
# Print one version's section body from CHANGELOG.md, without its heading --
# the GitHub Release is already titled by its tag. Used both to preview a
# release's notes before tagging and, in CI, to fail the build early when a
# tag has no matching section instead of publishing an image with no notes.
set -eu

cd "$(dirname "$0")/.."

version="${1:?usage: changelog_section.sh <version, e.g. 0.1.0>}"

section=$(awk -v heading="## v${version} " '
  found && /^## / { exit }
  found { print }
  index($0, heading) == 1 { found = 1 }
' CHANGELOG.md)

if [ -z "$section" ]; then
  echo "Error: CHANGELOG.md has no '## v${version} ...' section." >&2
  exit 1
fi

printf '%s\n' "$section"

#!/usr/bin/env sh
# Verify every handler link in the domain stories resolves to an existing path.
#
# Repo-agnostic: which link kinds exist and where they point lives in the
# links config, one `<kind> <path template>` per line. A template may use
# `{target}` for the whole link target and `{1}`, `{2}`, ... for its
# `/`-separated parts. Paths resolve against the working directory.
#
# Links inside inline code spans are skipped, so a format description can
# show the syntax without tripping the check.
set -eu

usage="usage: check_story_links.sh <stories-dir> <links-conf>"
stories_dir="${1:?$usage}"
links_conf="${2:?$usage}"

# A mistyped argument must not pass as "no broken links".
[ -d "$stories_dir" ] || { echo "Error: stories dir '$stories_dir' not found" >&2; exit 1; }
[ -f "$links_conf" ] || { echo "Error: links config '$links_conf' not found" >&2; exit 1; }

template_for() {
  awk -v kind="$1" '$1 == kind { print $2; exit }' "$links_conf"
}

resolve() {
  awk -v template="$1" -v target="$2" 'BEGIN {
    count = split(target, part, "/")
    gsub(/\{target\}/, target, template)
    for (i = 1; i <= count; i++) gsub("\\{" i "\\}", part[i], template)
    print template
  }'
}

link_errors() {
  story="$1"
  sed 's/`[^`]*`//g' "$story" |
    grep -n -o '\[[a-z_-]*: [^]]*\]' |
    while IFS=: read -r line link; do
      kind="${link#[}"
      kind="${kind%%:*}"
      target="${link#*: }"
      target="${target%]}"
      template=$(template_for "$kind")
      if [ -z "$template" ]; then
        echo "$story:$line: $link -> unknown link kind '$kind' (not in $links_conf)"
        continue
      fi
      path=$(resolve "$template" "$target")
      [ -e "$path" ] || echo "$story:$line: $link -> $path does not exist"
    done
}

errors=$(
  for story in "$stories_dir"/*.md; do
    [ -e "$story" ] || continue
    link_errors "$story"
  done
)

if [ -n "$errors" ]; then
  printf '%s\n' "$errors" >&2
  echo "Error: domain story links are broken. Fix the link, or the story if the handler was renamed or removed." >&2
  exit 1
fi

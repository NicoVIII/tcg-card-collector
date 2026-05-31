#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
SRC_DIR="$ROOT_DIR/server/src"
EXCEPTIONS_FILE="$ROOT_DIR/server/linting/architecture_exceptions.txt"

if [ ! -d "$SRC_DIR" ]; then
  echo "Missing source directory: $SRC_DIR"
  exit 1
fi

layer_of_module() {
  module="$1"
  first_segment=$(printf '%s' "$module" | cut -d'/' -f1)
  case "$first_segment" in
    domain|application|infrastructure|driver|common|composition)
      printf '%s' "$first_segment"
      ;;
    *)
      printf 'root'
      ;;
  esac
}

is_allowed_dependency() {
  source_layer="$1"
  target_layer="$2"

  case "$source_layer" in
    domain)
      [ "$target_layer" = "domain" ] || [ "$target_layer" = "common" ]
      ;;
    application)
      [ "$target_layer" = "application" ] || [ "$target_layer" = "domain" ] || [ "$target_layer" = "common" ]
      ;;
    infrastructure)
      [ "$target_layer" = "infrastructure" ] || [ "$target_layer" = "application" ] || [ "$target_layer" = "domain" ] || [ "$target_layer" = "common" ]
      ;;
    driver)
      [ "$target_layer" = "driver" ] || [ "$target_layer" = "application" ] || [ "$target_layer" = "domain" ] || [ "$target_layer" = "common" ]
      ;;
    common)
      [ "$target_layer" = "common" ]
      ;;
    composition|root)
      # Composition and root modules are wiring entrypoints and may reference any layer.
      true
      ;;
    *)
      false
      ;;
  esac
}

is_exception() {
  source_module="$1"
  target_module="$2"
  pair="$source_module -> $target_module"

  if [ ! -f "$EXCEPTIONS_FILE" ]; then
    return 1
  fi

  grep -Fxq "$pair" "$EXCEPTIONS_FILE"
}

error_count=0

for file in $(find "$SRC_DIR" -name '*.gleam' | sort); do
  rel_path=${file#"$SRC_DIR/"}
  source_module=${rel_path%.gleam}
  source_layer=$(layer_of_module "$source_module")

  imports=$(sed -n 's/^import[[:space:]]\+\(tcg_card_collector\/[A-Za-z0-9_\/]*\).*/\1/p' "$file")

  if [ -z "$imports" ]; then
    continue
  fi

  for full_target in $imports; do
    target_module=${full_target#tcg_card_collector/}
    target_layer=$(layer_of_module "$target_module")

    if is_allowed_dependency "$source_layer" "$target_layer"; then
      continue
    fi

    if is_exception "$source_module" "$target_module"; then
      continue
    fi

    echo "Architecture violation: $source_module ($source_layer) must not import $target_module ($target_layer)"
    error_count=$((error_count + 1))
  done
done

if [ "$error_count" -gt 0 ]; then
  echo "Architecture lint failed with $error_count violation(s)."
  exit 1
fi

echo "Architecture lint passed"

mod server
mod client-web

# pinned exactly: a floating patch can change snapshot computation and cause
# spurious drift (see issue #31); bump deliberately + re-snapshot
skir_version := "1.2.19"

# pinned exactly, same reasoning as skir_version
ajv_version := "5.0.0"

default:
  just --list

[private]
skir *args:
  if command -v bunx >/dev/null 2>&1; then \
    bunx skir@{{skir_version}} {{args}}; \
  else \
    npx skir@{{skir_version}} {{args}}; \
  fi

[group('skir')]
skir-gen:
  just skir gen

[group('skir')]
skir-format:
  just skir format

[group('skir')]
skir-snapshot:
  just skir snapshot

[group('skir')]
[group('check')]
skir-check:
  just skir format --ci
  sh ./scripts/check_skir_snapshot.sh {{skir_version}}

# Closes the gap ADR 0019 flagged: docs/portability/export.schema.json and
# the Gleam encoder (server/src/portability/driver/export_file.gleam) are two
# hand-written descriptions of the same shape. Every frozen fixture
# (server/test/portability/fixtures/) is a real encoder byte string, checked
# byte-identical by its own Gleam test — so validating each fixture against
# the schema here is validating the encoder's actual output against it
# (ADR 0020).
[group('check')]
portability-schema-check:
  #!/usr/bin/env bash
  set -euo pipefail
  fixtures=(server/test/portability/fixtures/*.json)
  if command -v bunx >/dev/null 2>&1; then
    bunx ajv-cli@{{ajv_version}} validate --spec=draft2020 \
      -s docs/portability/export.schema.json -d "${fixtures[@]}"
  else
    npx ajv-cli@{{ajv_version}} validate --spec=draft2020 \
      -s docs/portability/export.schema.json -d "${fixtures[@]}"
  fi

[group('dbmate')]
dbmate-install:
  sh ./scripts/install_dbmate.sh

[group('dbmate')]
dbmate-migrate:
  sh ./scripts/dbmate_up.sh

# preview a release's CHANGELOG.md section the way CI will read it
changelog-section version:
  sh ./scripts/changelog_section.sh {{version}}

devcontainer-shellcheck:
  find .devcontainer container -type f -name '*.sh' -print0 | xargs -0r shellcheck

dev:
  #!/usr/bin/env bash
  trap 'kill 0' EXIT
  just server::dev &
  just client-web::dev &
  wait

test: server::test client-web::test

# the one command that answers "may this be committed"; the module-level
# check recipes stay static-only so CI can run checks and tests as separate
# steps without running the tests twice
[group('check')]
check: skir-check portability-schema-check server::check client-web::check test

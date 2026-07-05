mod server
mod client-web

# pinned exactly: a floating patch can change snapshot computation and cause
# spurious drift (see issue #31); bump deliberately + re-snapshot
skir_version := "1.2.19"

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

[group('dbmate')]
dbmate-install:
  sh ./scripts/install_dbmate.sh

[group('dbmate')]
dbmate-migrate:
  sh ./scripts/dbmate_up.sh

devcontainer-shellcheck:
  find .devcontainer container -type f -name '*.sh' -print0 | xargs -0r shellcheck

dev:
  #!/usr/bin/env bash
  trap 'kill 0' EXIT
  just server::dev &
  just client-web::dev &
  wait

[group('check')]
check: skir-check server::check client-web::check

test: server::test client-web::test

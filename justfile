mod server
mod client-web

default:
  just --list

[private]
skir *args:
  bunx skir@1.2 {{args}}

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
  just skir snapshot --ci

[group('dbmate')]
dbmate-install:
  sh ./scripts/install_dbmate.sh

[group('dbmate')]
dbmate-migrate:
  sh ./scripts/dbmate_up.sh

devcontainer-shellcheck:
  find .devcontainer container -type f -name '*.sh' -print0 | xargs -0r shellcheck

dev: server::dev client-web::dev

[group('check')]
check: skir-check server::check client-web::check

test: server::test client-web::test

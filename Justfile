mod server
mod client 'client-web'

default:
  @just --list

dbmate-install:
  sh ./scripts/install_dbmate.sh

db-migrate:
  sh ./scripts/dbmate_up.sh

contract-alignment-check:
  ./scripts/check_contract_alignment.sh

contract-snapshot-check:
  ./scripts/check_contract_snapshot.sh

storage-smoke-check:
  ./scripts/check_storage_smoke.sh

backend-format-check:
  just server::format-check

backend-typecheck:
  just server::check

backend-architecture-lint:
  just server::lint

backend-test:
  just db-migrate
  just server::test

frontend-format-check:
  just client::format-check

frontend-lint:
  just client::lint

frontend-typecheck:
  just client::type-check

frontend-test:
  just client::test

check-backend:
  just backend-format-check
  just backend-typecheck
  just db-migrate
  just backend-test
  just storage-smoke-check
  just backend-architecture-lint

check-frontend:
  just frontend-format-check
  just frontend-lint
  just frontend-typecheck
  just frontend-test

check-all:
  just check-backend
  just check-frontend
  just contract-alignment-check

# Compatibility aliases
check-contract-alignment:
  just contract-alignment-check

check-contract-snapshot:
  just contract-snapshot-check

check-storage-smoke:
  just storage-smoke-check

dev-server:
  just server::run

dev-client:
  just client::dev

test:
  just server::test
  just client::test

check:
  just contract-alignment-check
  just contract-snapshot-check
  just check-backend
  just check-frontend

fix-format:
  just server::format
  just client::format

devcontainer-shellcheck:
  find .devcontainer container -type f -name '*.sh' -print0 | xargs -0r shellcheck

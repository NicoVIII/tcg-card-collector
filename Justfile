mod server
mod client 'client-web'

default:
  @just --list

check-backend:
  ./scripts/check_backend.sh

check-backend-fast:
  ./scripts/check_backend_fast.sh

check-frontend:
  ./scripts/check_frontend.sh

check-frontend-fast:
  ./scripts/check_frontend_fast.sh

check-all:
  ./scripts/check_all.sh

check-contract-alignment:
  ./scripts/check_contract_alignment.sh

check-contract-snapshot:
  ./scripts/check_contract_snapshot.sh

check-storage-smoke:
  ./scripts/check_storage_smoke.sh

dev-server:
  just server::run

dev-client:
  just client::dev

test:
  just server::test
  just client::test

check:
  just check-contract-alignment
  just check-contract-snapshot
  just server::format-check
  just server::check
  just server::lint
  just server::test
  just client::format-check
  just client::type-check
  just client::lint
  just client::test

fix-format:
  just server::format
  just client::format

devcontainer-shellcheck:
  find .devcontainer container -type f -name '*.sh' -print0 | xargs -0r shellcheck

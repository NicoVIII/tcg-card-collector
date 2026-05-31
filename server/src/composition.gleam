import gleam/io
import infrastructure/card_catalog/sqlite_repository as card_catalog_sqlite
import infrastructure/collection_import/sqlite_repository as collection_import_sqlite
import infrastructure/inventory_planning/sqlite_repository as inventory_planning_sqlite

pub fn boot_message() -> String {
  "tcg-card-collector composition ready"
}

pub fn log_boot_message() -> Nil {
  io.println(boot_message())
}

pub fn card_catalog_repository() {
  card_catalog_sqlite.new()
}

pub fn collection_import_repository() {
  collection_import_sqlite.new()
}

pub fn inventory_planning_repository() {
  inventory_planning_sqlite.new()
}

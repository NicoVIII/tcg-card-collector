import application/card_catalog/ports as card_catalog_ports
import application/collection_import/ports as collection_import_ports
import application/inventory_planning/ports as inventory_planning_ports
import application/settings/ports as settings_ports
import gleam/io
import infrastructure/card_catalog/sqlite_repository as card_catalog_sqlite
import infrastructure/collection_import/sqlite_repository as collection_import_sqlite
import infrastructure/inventory_planning/sqlite_repository as inventory_planning_sqlite
import infrastructure/settings/sqlite_repository as settings_sqlite

pub type Dependencies {
  Dependencies(
    card_catalog_repository: card_catalog_ports.CatalogRepository,
    collection_import_repository: collection_import_ports.CollectionImportRepository,
    inventory_planning_repository: inventory_planning_ports.InventoryPlanningRepository,
    settings_repository: settings_ports.SettingsRepository,
  )
}

fn boot_message() -> String {
  "tcg-card-collector composition ready"
}

pub fn log_boot_message() -> Nil {
  io.println(boot_message())
}

pub fn dependencies() -> Dependencies {
  Dependencies(
    card_catalog_repository: card_catalog_sqlite.new(),
    collection_import_repository: collection_import_sqlite.new(),
    inventory_planning_repository: inventory_planning_sqlite.new(),
    settings_repository: settings_sqlite.new(),
  )
}

import application/collection_import/ports as collection_import_ports
import application/commands/database/refresh/ports as refresh_ports
import application/inventory_planning/ports as inventory_planning_ports
import application/queries/database/list_cards/ports as list_cards_ports
import application/settings/ports as settings_ports
import gleam/io
import infrastructure/adapters/collection_import/sqlite_repository as collection_import_sqlite
import infrastructure/adapters/commands/database/refresh/adapter as refresh_adapter
import infrastructure/adapters/inventory_planning/sqlite_repository as inventory_planning_sqlite
import infrastructure/adapters/queries/database/list_cards/adapter as list_cards_adapter
import infrastructure/adapters/settings/sqlite_repository as settings_sqlite

pub type Dependencies {
  Dependencies(
    refresh_database_port: refresh_ports.RefreshDatabasePort,
    list_database_cards_port: list_cards_ports.ListCardsPort,
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
    refresh_database_port: refresh_adapter.new(),
    list_database_cards_port: list_cards_adapter.new(),
    collection_import_repository: collection_import_sqlite.new(),
    inventory_planning_repository: inventory_planning_sqlite.new(),
    settings_repository: settings_sqlite.new(),
  )
}

import application/commands/catalog/refresh/ports as refresh_ports
import application/commands/collection/import_collection/ports as import_collection_ports
import application/commands/inventory_planning/delete_rule/ports as delete_rule_ports
import application/commands/inventory_planning/upsert_rule/ports as upsert_rule_ports
import application/commands/settings/update/ports as update_settings_ports
import application/queries/catalog/list_cards/ports as list_cards_ports
import application/queries/collection/latest_status/ports as latest_status_ports
import application/queries/inventory_planning/list_rules/ports as list_rules_ports
import application/queries/inventory_planning/projection/ports as projection_ports
import application/queries/settings/get/ports as get_settings_ports
import gleam/io
import infrastructure/adapters/commands/catalog/refresh/adapter as refresh_adapter
import infrastructure/adapters/commands/collection/import_collection/adapter as import_collection_adapter
import infrastructure/adapters/commands/inventory_planning/delete_rule/adapter as delete_rule_adapter
import infrastructure/adapters/commands/inventory_planning/upsert_rule/adapter as upsert_rule_adapter
import infrastructure/adapters/commands/settings/update/adapter as update_settings_adapter
import infrastructure/adapters/queries/catalog/list_cards/adapter as list_cards_adapter
import infrastructure/adapters/queries/collection/latest_status/adapter as latest_status_adapter
import infrastructure/adapters/queries/inventory_planning/list_rules/adapter as list_rules_adapter
import infrastructure/adapters/queries/inventory_planning/projection/adapter as projection_adapter
import infrastructure/adapters/queries/settings/get/adapter as get_settings_adapter

pub type Dependencies {
  Dependencies(
    refresh_catalog_port: refresh_ports.RefreshCatalogPort,
    list_catalog_cards_port: list_cards_ports.ListCatalogCardsPort,
    import_collection_port: import_collection_ports.ImportCollectionPort,
    latest_import_status_port: latest_status_ports.LatestImportStatusPort,
    upsert_inventory_rule_port: upsert_rule_ports.UpsertInventoryRulePort,
    delete_inventory_rule_port: delete_rule_ports.DeleteInventoryRulePort,
    list_inventory_rules_port: list_rules_ports.ListInventoryRulesPort,
    inventory_projection_port: projection_ports.InventoryProjectionPort,
    update_settings_port: update_settings_ports.UpdateSettingsPort,
    get_settings_port: get_settings_ports.GetSettingsPort,
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
    refresh_catalog_port: refresh_adapter.new(),
    list_catalog_cards_port: list_cards_adapter.new(),
    import_collection_port: import_collection_adapter.new(),
    latest_import_status_port: latest_status_adapter.new(),
    upsert_inventory_rule_port: upsert_rule_adapter.new(),
    delete_inventory_rule_port: delete_rule_adapter.new(),
    list_inventory_rules_port: list_rules_adapter.new(),
    inventory_projection_port: projection_adapter.new(),
    update_settings_port: update_settings_adapter.new(),
    get_settings_port: get_settings_adapter.new(),
  )
}

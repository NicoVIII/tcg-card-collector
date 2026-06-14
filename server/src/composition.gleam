import catalog/application/commands/refresh/ports as refresh_ports
import catalog/application/queries/list_cards/ports as list_cards_ports
import catalog/infrastructure/adapters/commands/refresh/adapter as refresh_adapter
import catalog/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/ports as latest_status_ports
import collection/infrastructure/adapters/commands/import_collection/adapter as import_collection_adapter
import collection/infrastructure/adapters/queries/latest_status/adapter as latest_status_adapter
import gleam/io
import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_preferences/ports as get_preferences_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/infrastructure/adapters/commands/delete_rule/adapter as delete_rule_adapter
import inventory_planning/infrastructure/adapters/commands/update_preferences/adapter as update_preferences_adapter
import inventory_planning/infrastructure/adapters/commands/upsert_rule/adapter as upsert_rule_adapter
import inventory_planning/infrastructure/adapters/queries/get_preferences/adapter as get_preferences_adapter
import inventory_planning/infrastructure/adapters/queries/list_rules/adapter as list_rules_adapter
import inventory_planning/infrastructure/adapters/queries/projection/adapter as projection_adapter

pub type Dependencies {
  Dependencies(
    refresh_catalog_ports: refresh_ports.RefreshCatalogPorts,
    list_catalog_cards_port: list_cards_ports.ListCatalogCardsPort,
    import_collection_ports: import_collection_ports.ImportCollectionPorts,
    latest_import_status_port: latest_status_ports.LatestImportStatusPort,
    upsert_inventory_rule_port: upsert_rule_ports.UpsertInventoryRulePort,
    delete_inventory_rule_port: delete_rule_ports.DeleteInventoryRulePort,
    list_inventory_rules_port: list_rules_ports.ListInventoryRulesPort,
    inventory_projection_ports: projection_ports.InventoryProjectionPorts,
    update_planning_preferences_port: update_preferences_ports.UpdatePlanningPreferencesPort,
    get_planning_preferences_port: get_preferences_ports.GetPlanningPreferencesPort,
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
    refresh_catalog_ports: refresh_adapter.new(),
    list_catalog_cards_port: list_cards_adapter.new(),
    import_collection_ports: import_collection_adapter.new(),
    latest_import_status_port: latest_status_adapter.new(),
    upsert_inventory_rule_port: upsert_rule_adapter.new(),
    delete_inventory_rule_port: delete_rule_adapter.new(),
    list_inventory_rules_port: list_rules_adapter.new(),
    inventory_projection_ports: projection_adapter.new(),
    update_planning_preferences_port: update_preferences_adapter.new(),
    get_planning_preferences_port: get_preferences_adapter.new(),
  )
}

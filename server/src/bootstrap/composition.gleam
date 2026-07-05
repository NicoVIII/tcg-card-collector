import catalog/driver/dependencies.{
  type Dependencies as CatalogDependencies, Dependencies as CatalogDependencies,
} as _
import catalog/infrastructure/adapters/commands/refresh/adapter as refresh_adapter
import catalog/infrastructure/adapters/queries/get_cards/adapter as get_cards_adapter
import catalog/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter
import catalog/infrastructure/adapters/queries/refresh_status/adapter as refresh_status_adapter
import collection/driver/dependencies.{
  type Dependencies as CollectionDependencies,
  Dependencies as CollectionDependencies,
} as _
import collection/infrastructure/adapters/commands/add_cards/adapter as add_cards_adapter
import collection/infrastructure/adapters/commands/import_collection/adapter as import_collection_adapter
import collection/infrastructure/adapters/queries/list_cards/adapter as list_collection_cards_adapter
import gleam/erlang/process
import gleam/io
import insights/driver/dependencies.{
  type Dependencies as InsightsDependencies,
  Dependencies as InsightsDependencies,
} as _
import insights/infrastructure/adapters/commands/mark_target_set/adapter as mark_target_set_adapter
import insights/infrastructure/adapters/commands/unmark_target_set/adapter as unmark_target_set_adapter
import insights/infrastructure/adapters/queries/set_completion/adapter as set_completion_adapter
import inventory_planning/driver/dependencies.{
  type Dependencies as InventoryPlanningDependencies,
  Dependencies as InventoryPlanningDependencies,
} as _
import inventory_planning/infrastructure/adapters/commands/delete_rule/adapter as delete_rule_adapter
import inventory_planning/infrastructure/adapters/commands/update_bulk_spec/adapter as update_bulk_spec_adapter
import inventory_planning/infrastructure/adapters/commands/update_preferences/adapter as update_preferences_adapter
import inventory_planning/infrastructure/adapters/commands/upsert_rule/adapter as upsert_rule_adapter
import inventory_planning/infrastructure/adapters/queries/get_bulk_spec/adapter as get_bulk_spec_adapter
import inventory_planning/infrastructure/adapters/queries/get_preferences/adapter as get_preferences_adapter
import inventory_planning/infrastructure/adapters/queries/list_rules/adapter as list_rules_adapter
import inventory_planning/infrastructure/adapters/queries/projection/adapter as projection_adapter

pub type Dependencies {
  Dependencies(
    catalog: CatalogDependencies,
    collection: CollectionDependencies,
    inventory_planning: InventoryPlanningDependencies,
    insights: InsightsDependencies,
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
    catalog: CatalogDependencies(
      refresh_catalog_ports: refresh_adapter.new(),
      list_catalog_cards_port: list_cards_adapter.new(),
      get_catalog_cards_port: get_cards_adapter.new(),
      get_refresh_status_port: refresh_status_adapter.new(),
      refresh_worker_name: process.new_name("catalog_refresh_worker"),
    ),
    collection: CollectionDependencies(
      import_collection_port: import_collection_adapter.new(),
      add_cards_port: add_cards_adapter.new(),
      list_collection_cards_port: list_collection_cards_adapter.new(),
    ),
    inventory_planning: InventoryPlanningDependencies(
      upsert_inventory_rule_port: upsert_rule_adapter.new(),
      delete_inventory_rule_port: delete_rule_adapter.new(),
      list_inventory_rules_port: list_rules_adapter.new(),
      inventory_projection_ports: projection_adapter.new(),
      update_planning_preferences_port: update_preferences_adapter.new(),
      get_planning_preferences_port: get_preferences_adapter.new(),
      get_bulk_spec_port: get_bulk_spec_adapter.new(),
      update_bulk_spec_port: update_bulk_spec_adapter.new(),
    ),
    insights: InsightsDependencies(
      mark_target_set_port: mark_target_set_adapter.new(),
      unmark_target_set_port: unmark_target_set_adapter.new(),
      set_completion_ports: set_completion_adapter.new(),
    ),
  )
}

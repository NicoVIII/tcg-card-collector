import card_catalog/driver/dependencies.{
  type Dependencies as CatalogDependencies, Dependencies as CatalogDependencies,
} as _
import card_catalog/infrastructure/adapters/commands/refresh/adapter as refresh_adapter
import card_catalog/infrastructure/adapters/queries/get_cards/adapter as get_cards_adapter
import card_catalog/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter
import card_catalog/infrastructure/adapters/queries/refresh_status/adapter as refresh_status_adapter
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/commands/remove_cards/ports as remove_cards_ports
import collection/driver/dependencies.{
  type Dependencies as CollectionDependencies,
  Dependencies as CollectionDependencies,
} as _
import collection/infrastructure/adapters/commands/add_cards/adapter as add_cards_adapter
import collection/infrastructure/adapters/commands/import_collection/adapter as import_collection_adapter
import collection/infrastructure/adapters/commands/remove_cards/adapter as remove_cards_adapter
import collection/infrastructure/adapters/queries/list_cards/adapter as list_collection_cards_adapter
import gleam/erlang/process
import gleam/io
import gleam/string
import insights/driver/dependencies.{
  type Dependencies as InsightsDependencies,
  Dependencies as InsightsDependencies,
} as _
import insights/infrastructure/adapters/commands/mark_target_set/adapter as mark_target_set_adapter
import insights/infrastructure/adapters/commands/unmark_target_set/adapter as unmark_target_set_adapter
import insights/infrastructure/adapters/queries/set_completion/adapter as set_completion_adapter
import inventory_planning/application/commands/reconcile_placed_ledger/handler as reconcile_placed_ledger_handler
import inventory_planning/driver/dependencies.{
  type Dependencies as InventoryPlanningDependencies,
  Dependencies as InventoryPlanningDependencies,
} as _
import inventory_planning/infrastructure/adapters/commands/delete_rule/adapter as delete_rule_adapter
import inventory_planning/infrastructure/adapters/commands/mark_cards_placed/adapter as mark_cards_placed_adapter
import inventory_planning/infrastructure/adapters/commands/reconcile_placed_ledger/adapter as reconcile_placed_ledger_adapter
import inventory_planning/infrastructure/adapters/commands/relocate_placed_cards/adapter as relocate_placed_cards_adapter
import inventory_planning/infrastructure/adapters/commands/reorder_rules/adapter as reorder_rules_adapter
import inventory_planning/infrastructure/adapters/commands/unmark_cards_placed/adapter as unmark_cards_placed_adapter
import inventory_planning/infrastructure/adapters/commands/update_bulk_spec/adapter as update_bulk_spec_adapter
import inventory_planning/infrastructure/adapters/commands/upsert_rule/adapter as upsert_rule_adapter
import inventory_planning/infrastructure/adapters/queries/get_bulk_spec/adapter as get_bulk_spec_adapter
import inventory_planning/infrastructure/adapters/queries/list_rules/adapter as list_rules_adapter
import inventory_planning/infrastructure/adapters/queries/placed_ledger/adapter as placed_ledger_adapter
import inventory_planning/infrastructure/adapters/queries/projection/adapter as projection_adapter
import shared/application/event_bus

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

// A reconciliation failure is logged and swallowed rather than propagated:
// the publisher already committed its own write, so failing its response
// would only invite a retry that double-decrements the collection - ADR 0011.
fn reconcile_placed_ledger_subscriber() -> fn(Nil) -> Result(Nil, String) {
  let ports = reconcile_placed_ledger_adapter.new()
  fn(_event) {
    case
      reconcile_placed_ledger_handler.execute(
        reconcile_placed_ledger_handler.ReconcilePlacedLedgerCommand,
        ports,
      )
    {
      Ok(Nil) -> Nil
      Error(error) -> io.println("[reconcile][error] " <> string.inspect(error))
    }
    Ok(Nil)
  }
}

pub fn dependencies() -> Dependencies {
  let collection_changed_bus =
    event_bus.new([reconcile_placed_ledger_subscriber()])
  let notify_collection_changed = fn(_: Nil) {
    event_bus.publish(collection_changed_bus, Nil)
  }

  Dependencies(
    catalog: CatalogDependencies(
      refresh_catalog_ports: refresh_adapter.new(),
      list_catalog_cards_port: list_cards_adapter.new(),
      get_catalog_cards_port: get_cards_adapter.new(),
      get_refresh_status_port: refresh_status_adapter.new(),
      refresh_worker_name: process.new_name("catalog_refresh_worker"),
    ),
    collection: CollectionDependencies(
      import_collection_ports: import_collection_ports.ImportCollectionPorts(
        replace_collection: import_collection_adapter.new(),
        notify_changed: notify_collection_changed,
      ),
      add_cards_port: add_cards_adapter.new(),
      remove_cards_ports: remove_cards_ports.RemoveCardsPorts(
        decrement_cards: remove_cards_adapter.new(),
        notify_changed: notify_collection_changed,
      ),
      list_collection_cards_port: list_collection_cards_adapter.new(),
    ),
    inventory_planning: InventoryPlanningDependencies(
      upsert_inventory_rule_port: upsert_rule_adapter.new(),
      delete_inventory_rule_port: delete_rule_adapter.new(),
      reorder_inventory_rules_ports: reorder_rules_adapter.new(),
      list_inventory_rules_port: list_rules_adapter.new(),
      inventory_projection_ports: projection_adapter.new(),
      get_bulk_spec_port: get_bulk_spec_adapter.new(),
      update_bulk_spec_port: update_bulk_spec_adapter.new(),
      get_placed_ledger_port: placed_ledger_adapter.new(),
      mark_cards_placed_port: mark_cards_placed_adapter.new(),
      unmark_cards_placed_port: unmark_cards_placed_adapter.new(),
      relocate_placed_cards_port: relocate_placed_cards_adapter.new(),
    ),
    insights: InsightsDependencies(
      mark_target_set_port: mark_target_set_adapter.new(),
      unmark_target_set_port: unmark_target_set_adapter.new(),
      set_completion_ports: set_completion_adapter.new(),
    ),
  )
}

import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_bulk_spec/ports as get_bulk_spec_ports
import inventory_planning/application/queries/get_preferences/ports as get_preferences_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placed_ledger/ports as placed_ledger_ports
import inventory_planning/application/queries/projection/ports as projection_ports

pub type Dependencies {
  Dependencies(
    upsert_inventory_rule_port: upsert_rule_ports.UpsertInventoryRulePort,
    delete_inventory_rule_port: delete_rule_ports.DeleteInventoryRulePort,
    list_inventory_rules_port: list_rules_ports.ListInventoryRulesPort,
    inventory_projection_ports: projection_ports.InventoryProjectionPorts,
    update_planning_preferences_port: update_preferences_ports.UpdatePlanningPreferencesPort,
    get_planning_preferences_port: get_preferences_ports.GetPlanningPreferencesPort,
    get_bulk_spec_port: get_bulk_spec_ports.GetBulkSpecPort,
    update_bulk_spec_port: update_bulk_spec_ports.UpdateBulkSpecPort,
    get_placed_ledger_port: placed_ledger_ports.GetPlacedLedgerPort,
    mark_cards_placed_port: mark_cards_placed_ports.MarkCardsPlacedPort,
    unmark_cards_placed_port: unmark_cards_placed_ports.UnmarkCardsPlacedPort,
  )
}

import application/inventory_planning/ports
import gleam/list
import infrastructure/inventory_planning/inventory_rules_store

pub fn new() -> ports.InventoryPlanningRepository {
  ports.InventoryPlanningRepository(
    upsert_rule: fn(rule) {
      let ports.InventoryRuleWriteModel(
        id: id,
        location_name: location_name,
        expression: expression,
      ) = rule

      inventory_rules_store.upsert(id, location_name, expression)
    },
    list_rules: fn() {
      inventory_rules_store.list()
      |> list.map(fn(row) {
        let #(id, location_name, expression) = row
        ports.InventoryRuleReadModel(id:, location_name:, expression:)
      })
    },
    delete_rule: fn(rule_id) { inventory_rules_store.delete(rule_id) },
    inventory_projection: fn(sort_by, group_by) {
      inventory_rules_store.projection(sort_by, group_by)
      |> list.map(fn(row) {
        let #(location_name, card_name, set_code, quantity, group_value) = row
        ports.InventoryProjectionReadModel(
          location_name: location_name,
          card_name: card_name,
          set_code: set_code,
          quantity: quantity,
          group_value: group_value,
        )
      })
    },
  )
}

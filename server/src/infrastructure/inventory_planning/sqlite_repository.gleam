import application/inventory_planning/ports
import gleam/list

@external(erlang, "inventory_rules_store", "upsert")
fn store_upsert(id: String, location_name: String, expression: String) -> Nil

@external(erlang, "inventory_rules_store", "list")
fn store_list() -> List(#(String, String, String))

@external(erlang, "inventory_rules_store", "delete")
fn store_delete(id: String) -> Nil

@external(erlang, "inventory_rules_store", "projection")
fn store_projection(
  sort_by: String,
  group_by: String,
) -> List(#(String, String, String, Int, String))

@external(erlang, "inventory_rules_store", "clear")
fn store_clear() -> Nil

pub fn new() -> ports.InventoryPlanningRepository {
  ports.InventoryPlanningRepository(
    upsert_rule: fn(rule) {
      let ports.InventoryRuleWriteModel(
        id: id,
        location_name: location_name,
        expression: expression,
      ) = rule

      store_upsert(id, location_name, expression)
    },
    list_rules: fn() {
      store_list()
      |> list.map(fn(row) {
        let #(id, location_name, expression) = row
        ports.InventoryRuleReadModel(id:, location_name:, expression:)
      })
    },
    delete_rule: fn(rule_id) { store_delete(rule_id) },
    inventory_projection: fn(sort_by, group_by) {
      store_projection(sort_by, group_by)
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

pub fn reset_for_tests() -> Nil {
  store_clear()
}

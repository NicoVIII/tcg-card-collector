import application/inventory_planning/ports
import gleam/list

@external(erlang, "inventory_rules_store", "upsert")
fn store_upsert(id: String, location_name: String, expression: String) -> Nil

@external(erlang, "inventory_rules_store", "list")
fn store_list() -> List(#(String, String, String))

@external(erlang, "inventory_rules_store", "delete")
fn store_delete(id: String) -> Nil

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
    inventory_projection: fn(_sort_by, _group_by) { [] },
  )
}

pub fn reset_for_tests() -> Nil {
  store_clear()
}

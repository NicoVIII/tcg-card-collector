import application/queries/inventory_planning/projection/ports
import gleam/list
import infrastructure/stores/inventory_planning/inventory_rules_store

pub fn new() -> ports.InventoryProjectionPort {
  ports.InventoryProjectionPort(projection: fn(sort_by, group_by) {
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
  })
}

import application/queries/inventory_planning/projection/ports
import catalog/infrastructure/stores/catalog_store
import gleam/list
import gleam/option.{None, Some}
import infrastructure/stores/collection/collection_store
import infrastructure/stores/inventory_planning/inventory_rules_store

pub fn new() -> ports.InventoryProjectionPort {
  ports.InventoryProjectionPort(
    snapshot_rows: fn() {
      collection_store.snapshot_rows()
      |> list.map(fn(row) {
        let #(set_code, collector_number, quantity) = row
        ports.SnapshotRow(
          set_code: set_code,
          collector_number: collector_number,
          quantity: quantity,
        )
      })
    },
    catalog_name: fn(set_code, collector_number) {
      let names = catalog_store.name_lookup()
      case
        list.find(names, fn(entry) {
          let #(s, c, _) = entry
          s == set_code && c == collector_number
        })
      {
        Ok(#(_, _, name)) -> Some(name)
        Error(_) -> None
      }
    },
    rules: fn() {
      inventory_rules_store.list()
      |> list.map(fn(rule) {
        let #(_, location_name, expression) = rule
        ports.RuleRow(location_name: location_name, expression: expression)
      })
    },
  )
}

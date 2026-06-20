import catalog/infrastructure/daos/catalog_dao
import collection/infrastructure/stores/collection_store
import gleam/list
import gleam/option.{None, Some}
import inventory_planning/application/queries/projection/ports
import inventory_planning/infrastructure/stores/inventory_rules_store

pub fn new() -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: snapshot_rows_adapter(),
    catalog_name: catalog_name_adapter(),
    rules: rules_adapter(),
  )
}

fn snapshot_rows_adapter() -> ports.SnapshotRowsPort {
  fn() {
    collection_store.snapshot_rows()
    |> list.map(fn(row) {
      let #(set_code, collector_number, quantity) = row
      ports.SnapshotRow(
        set_code: set_code,
        collector_number: collector_number,
        quantity: quantity,
      )
    })
  }
}

fn catalog_name_adapter() -> ports.CatalogNamePort {
  fn(set_code, collector_number) {
    let names = catalog_dao.name_lookup()
    case
      list.find(names, fn(entry) {
        let #(s, c, _) = entry
        s == set_code && c == collector_number
      })
    {
      Ok(#(_, _, name)) -> Some(name)
      Error(_) -> None
    }
  }
}

fn rules_adapter() -> ports.RulesPort {
  fn() {
    inventory_rules_store.list()
    |> list.map(fn(rule) {
      let #(_, location_name, expression) = rule
      ports.RuleRow(location_name: location_name, expression: expression)
    })
  }
}

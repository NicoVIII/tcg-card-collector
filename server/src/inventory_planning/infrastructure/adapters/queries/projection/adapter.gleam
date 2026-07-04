import catalog/driver/gleam/catalog_api
import collection/driver/gleam/collection_api
import gleam/dict
import gleam/list
import gleam/result
import inventory_planning/application/queries/projection/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: snapshot_rows_adapter(),
    catalog_names: catalog_names_adapter(),
    rules: rules_adapter(),
  )
}

fn snapshot_rows_adapter() -> ports.SnapshotRowsPort {
  fn() {
    use cards <- result.try(collection_api.list_cards())
    Ok(
      list.map(cards, fn(card) {
        ports.SnapshotRow(
          set_code: card.set_code,
          collector_number: card.collector_number,
          quantity: card.quantity,
        )
      }),
    )
  }
}

fn catalog_names_adapter() -> ports.CatalogNamesPort {
  fn(keys) {
    catalog_api.get_cards(keys)
    |> list.map(fn(card) {
      #(#(card.set_code, card.collector_number), card.name)
    })
    |> dict.from_list
  }
}

fn rules_adapter() -> ports.RulesPort {
  fn() {
    inventory_rules_dao.list()
    |> list.map(fn(rule) {
      let #(_, location_name, expression) = rule
      ports.RuleRow(location_name: location_name, expression: expression)
    })
  }
}

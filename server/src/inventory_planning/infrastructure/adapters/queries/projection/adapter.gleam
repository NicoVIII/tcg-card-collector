import catalog/driver/gleam/catalog_api
import collection/driver/gleam/collection_api
import gleam/dict
import gleam/list
import gleam/result
import inventory_planning/application/queries/projection/ports
import inventory_planning/infrastructure/daos/bulk_spec_dao
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: snapshot_rows_adapter(),
    catalog_attributes: catalog_attributes_adapter(),
    rules: rules_adapter(),
    set_release_dates: set_release_dates_adapter(),
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

fn catalog_attributes_adapter() -> ports.CatalogAttributesPort {
  fn(keys) {
    catalog_api.get_cards(keys)
    |> list.map(fn(card) {
      #(
        #(card.set_code, card.collector_number),
        ports.CatalogAttributes(
          name: card.name,
          rarity: card.rarity,
          oracle_id: card.oracle_id,
          color_identity: card.color_identity,
          type_line: card.type_line,
          released_at: card.released_at,
        ),
      )
    })
    |> dict.from_list
  }
}

fn set_release_dates_adapter() -> ports.SetReleaseDatesPort {
  fn(set_codes) { catalog_api.get_set_release_dates(set_codes) }
}

fn rules_adapter() -> ports.RulesPort {
  fn() {
    let rules =
      inventory_rules_dao.list()
      |> list.map(fn(rule) {
        let #(id, location_name, expression, position, selector, sort_keys) =
          rule
        ports.RuleRow(
          id: id,
          position: position,
          selector: selector,
          expression: expression,
          location_name: location_name,
          sort_keys: sort_keys,
        )
      })
    let #(bulk_location, bulk_sort_keys) = bulk_spec_dao.get()
    ports.RulesModel(
      rules: rules,
      bulk: ports.BulkSpecRow(
        location_name: bulk_location,
        sort_keys: bulk_sort_keys,
      ),
    )
  }
}

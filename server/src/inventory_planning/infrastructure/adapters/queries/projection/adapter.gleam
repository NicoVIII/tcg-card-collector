import card_catalog/driver/gleam/catalog_api
import collection/driver/gleam/collection_api
import gleam/dict
import gleam/list
import gleam/result
import inventory_planning/application/queries/projection/ports
import inventory_planning/infrastructure/daos/bulk_spec_dao
import inventory_planning/infrastructure/daos/inventory_rules_dao
import shared/domain/card_key

pub fn new() -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: snapshot_rows_adapter(),
    catalog_attributes: catalog_attributes_adapter(),
    rules: rules_adapter(),
    set_metadata: set_metadata_adapter(),
  )
}

fn snapshot_rows_adapter() -> ports.SnapshotRowsPort {
  fn() {
    use cards <- result.try(collection_api.list_cards())
    Ok(
      list.map(cards, fn(card) {
        ports.SnapshotRow(
          set_code: card_key.set_code_string(card.key),
          collector_number: card_key.collector_number_string(card.key),
          quantity: card.quantity,
        )
      }),
    )
  }
}

fn catalog_attributes_adapter() -> ports.CatalogAttributesPort {
  fn(keys) {
    use cards <- result.map(catalog_api.get_cards(keys))
    cards
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

fn set_metadata_adapter() -> ports.SetMetadataPort {
  fn(set_codes) {
    use metadata <- result.map(catalog_api.get_set_metadata(set_codes))
    dict.map_values(metadata, fn(_code, meta) {
      ports.SetMetadataRow(
        released_at: meta.released_at,
        parent_set_code: meta.parent_set_code,
      )
    })
  }
}

fn rules_adapter() -> ports.RulesPort {
  fn() {
    use rule_tuples <- result.try(inventory_rules_dao.list())
    use #(bulk_location, bulk_sort_keys) <- result.map(bulk_spec_dao.get())
    let rules =
      rule_tuples
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
    ports.RulesModel(
      rules: rules,
      bulk: ports.BulkSpecRow(
        location_name: bulk_location,
        sort_keys: bulk_sort_keys,
      ),
    )
  }
}

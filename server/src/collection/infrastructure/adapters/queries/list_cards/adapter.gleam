import card_catalog/driver/gleam/catalog_api
import collection/application/queries/list_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result
import gleam/set
import shared/domain/card_key
import shared/domain/copy_key

pub fn new() -> ports.ListCollectionCardsPorts {
  ports.ListCollectionCardsPorts(
    list_cards: list_cards_adapter(),
    card_keys_named: card_keys_named_adapter(),
  )
}

fn list_cards_adapter() -> ports.ListCardsPort {
  fn() {
    use rows <- result.try(collection_dao.list_cards())
    // Stored rows were written from a CopyKey, so they parse with the strict
    // constructor; a failure means corrupt stored data and fails the query
    // (ADR 0008).
    list.try_map(rows, fn(row) {
      let collection_dao.CardRow(
        set_code:,
        collector_number:,
        finish:,
        language:,
        quantity:,
      ) = row
      case copy_key.new(set_code:, collector_number:, finish:, language:) {
        Ok(key) -> Ok(ports.CollectionCopyReadModel(key:, quantity:))
        Error(error) ->
          Error(
            "corrupt collection row "
            <> set_code
            <> "/"
            <> collector_number
            <> ": "
            <> copy_key.describe_error(error),
          )
      }
    })
  }
}

// Catalog rows are already canonical (parsed once at Card Catalog's own sync
// boundary, ADR 0008), so the strict constructor is the right one here too.
fn card_keys_named_adapter() -> ports.CardKeysNamedPort {
  fn(name) {
    use rows <- result.try(catalog_api.list_card_keys_named(name))
    use keys <- result.try(
      list.try_map(rows, fn(row) {
        case
          card_key.new(
            set_code: row.set_code,
            collector_number: row.collector_number,
          )
        {
          Ok(key) -> Ok(key)
          Error(error) ->
            Error(
              "corrupt catalog key "
              <> row.set_code
              <> "/"
              <> row.collector_number
              <> ": "
              <> card_key.describe_error(error),
            )
        }
      }),
    )
    Ok(set.from_list(keys))
  }
}

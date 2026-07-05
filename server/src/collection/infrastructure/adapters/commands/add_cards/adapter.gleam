import collection/application/commands/add_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import shared/domain/card_key

pub fn new() -> ports.UpsertCardsPort {
  fn(rows) {
    collection_dao.upsert_cards(
      list.map(rows, fn(row) {
        let ports.CollectionRowWriteModel(key: key, quantity: quantity) = row
        #(
          card_key.set_code_string(key),
          card_key.collector_number_string(key),
          quantity,
        )
      }),
    )
  }
}

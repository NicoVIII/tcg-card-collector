import collection/application/commands/import_collection/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import shared/domain/card_key

pub fn new() -> ports.ReplaceCollectionPort {
  fn(rows) {
    collection_dao.replace_collection(
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

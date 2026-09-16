import collection/application/commands/import_collection/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import shared/domain/copy_key

pub fn new() -> ports.ReplaceCollectionPort {
  fn(rows) {
    collection_dao.replace_collection(
      list.map(rows, fn(row) {
        let ports.CollectionRowWriteModel(key: key, quantity: quantity) = row
        collection_dao.CardRow(
          set_code: copy_key.set_code_string(key),
          collector_number: copy_key.collector_number_string(key),
          finish: copy_key.finish_string(key),
          language: copy_key.language_string(key),
          quantity:,
        )
      }),
    )
  }
}

import collection/application/commands/remove_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result
import shared/domain/copy_key

pub fn owned_quantity() -> ports.OwnedQuantityPort {
  fn(key) {
    use rows <- result.try(collection_dao.copies_of(
      copy_key.set_code_string(key),
      copy_key.collector_number_string(key),
    ))
    Ok(
      rows
      |> list.filter(fn(row) {
        row.finish == copy_key.finish_string(key)
        && row.language == copy_key.language_string(key)
      })
      |> list.fold(0, fn(sum, row) { sum + row.quantity }),
    )
  }
}

pub fn decrement_cards() -> ports.DecrementCardsPort {
  fn(rows) {
    collection_dao.decrement_cards(
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

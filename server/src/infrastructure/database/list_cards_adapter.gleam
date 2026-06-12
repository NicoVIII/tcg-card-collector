import application/queries/database/list_cards/ports
import gleam/list
import infrastructure/database/database_store

pub fn new() -> ports.ListCardsPort {
  ports.ListCardsPort(list_cards: fn() {
    database_store.list()
    |> list.map(fn(row) {
      let #(id, name, set_code) = row
      ports.DatabaseCardReadModel(id:, name:, set_code:)
    })
  })
}

import application/queries/catalog/list_cards/ports
import gleam/list
import infrastructure/stores/catalog/catalog_store

pub fn new() -> ports.ListCatalogCardsPort {
  ports.ListCatalogCardsPort(list_cards: fn() {
    catalog_store.list()
    |> list.map(fn(row) {
      let #(id, name, set_code) = row
      ports.CatalogCardReadModel(id:, name:, set_code:)
    })
  })
}

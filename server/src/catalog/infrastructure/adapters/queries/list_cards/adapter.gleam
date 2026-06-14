import catalog/application/queries/list_cards/ports
import catalog/infrastructure/stores/catalog_store
import gleam/list

pub fn new() -> ports.ListCatalogCardsPort {
  ports.ListCatalogCardsPort(list_cards: fn() {
    catalog_store.list()
    |> list.map(fn(row) {
      let #(id, name, set_code) = row
      ports.CatalogCardReadModel(id:, name:, set_code:)
    })
  })
}

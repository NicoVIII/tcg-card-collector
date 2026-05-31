import application/card_catalog/ports
import gleam/list
import infrastructure/card_catalog/card_catalog_store

pub fn new() -> ports.CatalogRepository {
  ports.CatalogRepository(
    refresh_catalog: fn() {
      case card_catalog_store.refresh() {
        Ok(_) -> Ok(Nil)
        Error(message) -> Error(ports.CatalogRefreshError(message: message))
      }
    },
    list_cards: fn() {
      card_catalog_store.list()
      |> list.map(fn(row) {
        let #(id, name, set_code) = row
        ports.CatalogCardReadModel(id:, name:, set_code:)
      })
    },
  )
}

pub fn seed_card(id: String, name: String, set_code: String) -> Nil {
  card_catalog_store.upsert(id, name, set_code)
}

pub fn reset_for_tests() -> Nil {
  card_catalog_store.clear()
}

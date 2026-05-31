import application/card_catalog/ports
import gleam/list

@external(erlang, "card_catalog_store", "upsert")
fn store_upsert(id: String, name: String, set_code: String) -> Nil

@external(erlang, "card_catalog_store", "list")
fn store_list() -> List(#(String, String, String))

@external(erlang, "card_catalog_store", "clear")
fn store_clear() -> Nil

pub fn new() -> ports.CatalogRepository {
  ports.CatalogRepository(refresh_catalog: fn() { Nil }, list_cards: fn() {
    store_list()
    |> list.map(fn(row) {
      let #(id, name, set_code) = row
      ports.CatalogCardReadModel(id:, name:, set_code:)
    })
  })
}

pub fn seed_card(id: String, name: String, set_code: String) -> Nil {
  store_upsert(id, name, set_code)
}

pub fn reset_for_tests() -> Nil {
  store_clear()
}

import application/card_catalog/ports

pub fn new() -> ports.CatalogRepository {
  ports.CatalogRepository(refresh_catalog: fn() { Nil }, list_cards: fn() {
    [
      ports.CatalogCardReadModel(
        id: "stub-1",
        name: "Stub Card",
        set_code: "STB",
      ),
    ]
  })
}

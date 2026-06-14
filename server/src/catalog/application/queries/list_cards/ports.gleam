pub type ListCatalogCardsPort {
  ListCatalogCardsPort(list_cards: fn() -> List(CatalogCardReadModel))
}

pub type CatalogCardReadModel {
  CatalogCardReadModel(id: String, name: String, set_code: String)
}

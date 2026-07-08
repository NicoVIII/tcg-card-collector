pub type CatalogCardKeyReadModel {
  CatalogCardKeyReadModel(set_code: String, collector_number: String)
}

pub type ListCatalogCardsPort {
  ListCatalogCardsPort(
    list_cards: fn() -> Result(List(CatalogCardKeyReadModel), String),
  )
}

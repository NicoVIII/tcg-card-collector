pub type CardReadModel {
  CardReadModel(
    set_code: String,
    collector_number: String,
    name: String,
    image_uri: String,
  )
}

pub type GetCatalogCardsPort {
  GetCatalogCardsPort(
    get_cards: fn(List(#(String, String))) -> List(CardReadModel),
  )
}

pub type CardReadModel {
  CardReadModel(
    set_code: String,
    collector_number: String,
    name: String,
    image_uri: String,
    rarity: String,
    oracle_id: String,
    color_identity: String,
    type_line: String,
    released_at: String,
  )
}

pub type GetCatalogCardsPort {
  GetCatalogCardsPort(
    get_cards: fn(List(#(String, String))) -> List(CardReadModel),
  )
}

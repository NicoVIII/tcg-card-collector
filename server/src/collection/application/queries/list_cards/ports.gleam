pub type CollectionCardReadModel {
  CollectionCardReadModel(
    set_code: String,
    collector_number: String,
    quantity: Int,
  )
}

pub type ListCollectionCardsPort {
  ListCollectionCardsPort(list_cards: fn() -> List(CollectionCardReadModel))
}

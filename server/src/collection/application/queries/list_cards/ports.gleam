import shared/domain/card_key.{type CardKey}

pub type CollectionCardReadModel {
  CollectionCardReadModel(key: CardKey, quantity: Int)
}

pub type CollectionCardPage {
  CollectionCardPage(cards: List(CollectionCardReadModel), total: Int)
}

pub type ListCollectionCardsPort {
  ListCollectionCardsPort(
    list_cards: fn() -> Result(List(CollectionCardReadModel), String),
  )
}

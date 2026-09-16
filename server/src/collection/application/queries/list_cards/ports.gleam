import shared/domain/card_key.{type CardKey}
import shared/domain/copy_key.{type CopyKey}

// One raw row from storage: the quantity owned of a single kind of copy.
pub type CollectionCopyReadModel {
  CollectionCopyReadModel(key: CopyKey, quantity: Int)
}

// One kind of copy within a printing's display group.
pub type OwnedCopy {
  OwnedCopy(finish: String, language: String, quantity: Int)
}

// A printing with every kind of copy owned of it — the grid shows one tile
// per printing with a badge per copy (ADR 0010: badges, not one tile per copy).
pub type OwnedPrinting {
  OwnedPrinting(key: CardKey, copies: List(OwnedCopy))
}

pub type CollectionCardPage {
  CollectionCardPage(printings: List(OwnedPrinting), total: Int)
}

pub type ListCollectionCardsPort {
  ListCollectionCardsPort(
    list_cards: fn() -> Result(List(CollectionCopyReadModel), String),
  )
}

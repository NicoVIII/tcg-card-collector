import gleam/set.{type Set}
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

pub type ListCardsPort =
  fn() -> Result(List(CollectionCopyReadModel), String)

// The Card Catalog keys whose name (case-insensitive substring) matches —
// read through card_catalog/driver/gleam (ADR 0016), called only when a name
// filter is present.
pub type CardKeysNamedPort =
  fn(String) -> Result(Set(CardKey), String)

pub type ListCollectionCardsPorts {
  ListCollectionCardsPorts(
    list_cards: ListCardsPort,
    card_keys_named: CardKeysNamedPort,
  )
}

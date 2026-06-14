import collection/domain/physical_card.{type PhysicalCard}
import gleam/list

pub type Collection {
  Collection(cards: List(PhysicalCard))
}

pub type CollectionError {
  RowCountMismatch
}

/// Build a Collection from a list of owned cards.
/// Fails if the number of cards does not match the caller's expected count,
/// enforcing the import invariant: what the client claims it sent is what
/// actually arrived and was valid.
pub fn from_cards(
  cards: List(PhysicalCard),
  expected_count: Int,
) -> Result(Collection, CollectionError) {
  case list.length(cards) == expected_count {
    True -> Ok(Collection(cards: cards))
    False -> Error(RowCountMismatch)
  }
}

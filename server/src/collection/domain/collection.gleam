import collection/domain/physical_card.{type PhysicalCard, PhysicalCard}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import shared/domain/card_key.{type CardKey}

pub opaque type Collection {
  Collection(entries: Dict(CardKey, physical_card.Quantity))
}

/// Normalizes a batch of owned cards into a Collection: cards sharing a key
/// are combined by summing their quantities, so key-uniqueness holds by
/// construction. Callers validate rows before building; there is no row-count
/// invariant here — how the batch reaches storage (replace vs upsert) is the
/// use case's concern, not the domain's.
pub fn from_cards(cards: List(PhysicalCard)) -> Collection {
  Collection(entries: entries_from_cards(cards))
}

fn entries_from_cards(
  cards: List(PhysicalCard),
) -> Dict(CardKey, physical_card.Quantity) {
  list.fold(cards, dict.new(), fn(acc, card) {
    dict.upsert(acc, card.key, fn(existing) {
      case existing {
        Some(quantity) -> physical_card.quantity_add(quantity, card.quantity)
        None -> card.quantity
      }
    })
  })
}

pub fn to_cards(collection: Collection) -> List(PhysicalCard) {
  collection.entries
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(key, quantity) = pair
    PhysicalCard(key: key, quantity: quantity)
  })
}

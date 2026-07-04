import collection/domain/physical_card.{type PhysicalCard, PhysicalCard}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import shared/domain/card_key.{type CardKey}

pub opaque type Collection {
  Collection(entries: Dict(CardKey, physical_card.Quantity))
}

pub type CollectionError {
  RowCountMismatch
}

/// Build a Collection from a list of owned cards.
/// Fails if the number of cards does not match the caller's expected count,
/// enforcing the import invariant: what the client claims it sent is what
/// actually arrived and was valid. Cards sharing a key are combined by
/// summing their quantities, so key-uniqueness holds by construction.
pub fn from_cards(
  cards: List(PhysicalCard),
  expected_count: Int,
) -> Result(Collection, CollectionError) {
  case list.length(cards) == expected_count {
    True -> Ok(Collection(entries: entries_from_cards(cards)))
    False -> Error(RowCountMismatch)
  }
}

/// Build a Collection from already-persisted cards, with no row-count
/// invariant to check — used for the previous snapshot in a delta import.
pub fn from_trusted_cards(cards: List(PhysicalCard)) -> Collection {
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

/// Merges `delta`'s cards into `base`, summing quantities for keys present
/// in both. `base` is trusted persisted state; `delta` is the newly
/// validated collection from the current import.
pub fn merge(base: Collection, delta: Collection) -> Collection {
  let merged =
    list.fold(dict.to_list(delta.entries), base.entries, fn(acc, pair) {
      let #(key, quantity) = pair
      dict.upsert(acc, key, fn(existing) {
        case existing {
          Some(existing_quantity) ->
            physical_card.quantity_add(existing_quantity, quantity)
          None -> quantity
        }
      })
    })
  Collection(entries: merged)
}

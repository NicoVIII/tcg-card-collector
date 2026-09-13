import gleam/bool
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/string
import shared/domain/card_key.{type CardKey}
import shared/domain/non_empty_string.{type NonEmptyString}

pub type PlacementError {
  InvalidKey
  EmptyLocation
  NonPositiveQuantity
}

// One physical placement: a card key, the location it was placed in, and how
// many copies. Opaque so the only way to hold one is through `new`, which
// guarantees a canonical key, a non-empty location, and a positive quantity.
pub opaque type Placement {
  Placement(key: CardKey, location: NonEmptyString, quantity: Int)
}

pub fn new(
  set_code set_code: String,
  collector_number collector_number: String,
  location location: String,
  quantity quantity: Int,
) -> Result(Placement, PlacementError) {
  use key <- result.try(
    card_key.from_user_input(set_code:, collector_number:)
    |> result.replace_error(InvalidKey),
  )
  use location_nes <- result.try(
    non_empty_string.new(string.trim(location))
    |> result.replace_error(EmptyLocation),
  )
  use <- bool.guard(quantity < 1, Error(NonPositiveQuantity))
  Ok(Placement(key:, location: location_nes, quantity:))
}

pub fn set_code_string(placement: Placement) -> String {
  card_key.set_code_string(placement.key)
}

pub fn collector_number_string(placement: Placement) -> String {
  card_key.collector_number_string(placement.key)
}

pub fn location(placement: Placement) -> String {
  non_empty_string.to_string(placement.location)
}

pub fn quantity(placement: Placement) -> Int {
  placement.quantity
}

type PlacementIdentity {
  PlacementIdentity(
    set_code: String,
    collector_number: String,
    location: String,
  )
}

fn identity(placement: Placement) -> PlacementIdentity {
  PlacementIdentity(
    set_code: card_key.set_code_string(placement.key),
    collector_number: card_key.collector_number_string(placement.key),
    location: location(placement),
  )
}

fn compare_identity(a: PlacementIdentity, b: PlacementIdentity) -> order.Order {
  string.compare(a.set_code, b.set_code)
  |> order.lazy_break_tie(fn() {
    string.compare(a.collector_number, b.collector_number)
  })
  |> order.lazy_break_tie(fn() { string.compare(a.location, b.location) })
}

/// Collapses placements sharing a (key, location) into one by summing their
/// quantities, returning them in a stable (key, location) order so a given
/// batch always persists identically.
pub fn merge(placements: List(Placement)) -> List(Placement) {
  placements
  |> list.fold(dict.new(), fn(acc, placement) {
    dict.upsert(acc, identity(placement), fn(existing) {
      case existing {
        Some(prev) ->
          Placement(..prev, quantity: prev.quantity + placement.quantity)
        None -> placement
      }
    })
  })
  |> dict.values
  |> list.sort(fn(a, b) { compare_identity(identity(a), identity(b)) })
}

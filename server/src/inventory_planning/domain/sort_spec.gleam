import gleam/int
import gleam/list
import gleam/option
import gleam/order.{type Order}
import gleam/string
import inventory_planning/domain/card_attributes.{type PlannedCard}
import shared/domain/card_key
import shared/domain/collector_number
import shared/domain/rarity
import shared/domain/set_code

// The vocabulary for ordering cards within a location — shared by the bulk
// remainder and each rule's bucket. A comma-separated DSL of these tokens names
// the sort; an empty list keeps the incoming canonical order.
pub type SortKey {
  ByColorIdentity
  ByCardType
  ByName
  BySetCode
  ByCollectorNumber
  ByRarity
  ByReleasedAt
  ByManaValue
}

fn parse_sort_key(raw: String) -> Result(SortKey, Nil) {
  case string.lowercase(string.trim(raw)) {
    "color_identity" -> Ok(ByColorIdentity)
    "type" -> Ok(ByCardType)
    "name" -> Ok(ByName)
    "set_code" -> Ok(BySetCode)
    "collector_number" -> Ok(ByCollectorNumber)
    "rarity" -> Ok(ByRarity)
    "released_at" -> Ok(ByReleasedAt)
    "cmc" -> Ok(ByManaValue)
    _ -> Error(Nil)
  }
}

fn sort_key_to_string(key: SortKey) -> String {
  case key {
    ByColorIdentity -> "color_identity"
    ByCardType -> "type"
    ByName -> "name"
    BySetCode -> "set_code"
    ByCollectorNumber -> "collector_number"
    ByRarity -> "rarity"
    ByReleasedAt -> "released_at"
    ByManaValue -> "cmc"
  }
}

// Comma-separated DSL, e.g. "color_identity,type,name". An empty string yields
// no sort keys (cards keep their incoming, canonical order).
pub fn parse_sort_keys(raw: String) -> Result(List(SortKey), Nil) {
  case string.trim(raw) {
    "" -> Ok([])
    trimmed ->
      trimmed
      |> string.split(",")
      |> list.try_map(parse_sort_key)
  }
}

pub fn sort_keys_to_string(keys: List(SortKey)) -> String {
  keys |> list.map(sort_key_to_string) |> string.join(",")
}

// Compares two cards under an ordered list of sort keys: the first key that
// distinguishes them decides, else they compare equal.
pub fn compare_cards(
  keys: List(SortKey),
  left: PlannedCard,
  right: PlannedCard,
) -> Order {
  case keys {
    [] -> order.Eq
    [key, ..rest] ->
      case compare_by(key, left, right) {
        order.Eq -> compare_cards(rest, left, right)
        other -> other
      }
  }
}

fn compare_by(key: SortKey, left: PlannedCard, right: PlannedCard) -> Order {
  case key {
    ByColorIdentity -> int.compare(color_rank(left), color_rank(right))
    ByCardType -> int.compare(type_rank(left), type_rank(right))
    ByName -> string.compare(left.name, right.name)
    BySetCode ->
      set_code.compare(
        card_key.set_code(left.key),
        card_key.set_code(right.key),
      )
    ByCollectorNumber ->
      collector_number.compare(
        card_key.collector_number(left.key),
        card_key.collector_number(right.key),
      )
    ByRarity -> int.compare(rarity_rank(left), rarity_rank(right))
    ByReleasedAt ->
      card_attributes.compare_release_earliest_first(
        left.released_at,
        right.released_at,
      )
    ByManaValue -> card_attributes.compare_cmc_lowest_first(left.cmc, right.cmc)
  }
}

// A card with no known color identity sorts as colorless (last group).
fn color_rank(card: PlannedCard) -> Int {
  card.color_identity
  |> option.map(card_attributes.color_identity_rank)
  |> option.unwrap(31)
}

// A card with no known type sorts as Other (last).
fn type_rank(card: PlannedCard) -> Int {
  card.card_type
  |> option.map(card_attributes.card_type_rank)
  |> option.unwrap(card_attributes.card_type_rank(card_attributes.Other))
}

// A card with no known rarity sorts last (rank above every real rarity).
fn rarity_rank(card: PlannedCard) -> Int {
  card.rarity
  |> option.map(card_attributes.rarity_rank)
  |> option.unwrap(card_attributes.rarity_rank(rarity.Mythic) + 1)
}

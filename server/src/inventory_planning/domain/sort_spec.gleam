import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/string
import inventory_planning/domain/card_attributes.{type PlannedCard}
import shared/domain/card_key
import shared/domain/collector_number
import shared/domain/language
import shared/domain/rarity
import shared/domain/release_date
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
  ByLanguage
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
    "language" -> Ok(ByLanguage)
    _ -> Error(Nil)
  }
}

// The DSL token a key round-trips through parse_sort_key; also the string a
// section part's key maps to before the codec turns it into the contract's
// SortKey enum (#138).
pub fn sort_key_to_string(key: SortKey) -> String {
  case key {
    ByColorIdentity -> "color_identity"
    ByCardType -> "type"
    ByName -> "name"
    BySetCode -> "set_code"
    ByCollectorNumber -> "collector_number"
    ByRarity -> "rarity"
    ByReleasedAt -> "released_at"
    ByManaValue -> "cmc"
    ByLanguage -> "language"
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
    ByLanguage ->
      card_attributes.compare_language_en_first(left.language, right.language)
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

// The section value a key groups a card under (#138) — always a coarsening of
// that key's own sort order, so two cards with equal category never sort
// apart and a key's categories are contiguous under the sort. `None` means
// the key yields no section at all: collector_number is unique per printing,
// so grouping by it would never merge anything, and any key placed after it
// in a DSL never distinguishes surviving ties either — sort_section stops the
// label there rather than emit a useless one-card-per-value key.
pub fn category(key: SortKey, card: PlannedCard) -> Option(String) {
  case key {
    ByColorIdentity ->
      Some(
        card.color_identity
        |> option.map(card_attributes.color_identity_label)
        // Ranks equal to real colorless (color_rank's fallback, above) —
        // the same bucket, so the same label.
        |> option.unwrap("Colorless"),
      )
    ByCardType ->
      Some(
        card.card_type
        |> option.map(card_attributes.card_type_to_string)
        |> option.unwrap(card_attributes.card_type_to_string(
          card_attributes.Other,
        )),
      )
    ByName -> Some(string.first(card.name) |> result.unwrap(""))
    BySetCode -> Some(card_key.set_code_string(card.key))
    ByCollectorNumber -> None
    ByRarity ->
      Some(
        card.rarity
        |> option.map(rarity.to_string)
        |> option.unwrap("unknown"),
      )
    ByReleasedAt ->
      Some(
        card.released_at
        |> option.map(release_year)
        |> option.unwrap("unknown"),
      )
    ByManaValue ->
      Some(
        card.cmc
        |> option.map(card_attributes.cmc_label)
        |> option.unwrap("unknown"),
      )
    ByLanguage -> Some(language.to_string(card.language))
  }
}

// The calendar year of a release date ("2020-01-01" -> "2020") — coarse
// enough to merge into a useful section; the exact date never repeats widely
// enough to group cards.
fn release_year(date: release_date.ReleaseDate) -> String {
  string.slice(release_date.to_string(date), at_index: 0, length: 4)
}

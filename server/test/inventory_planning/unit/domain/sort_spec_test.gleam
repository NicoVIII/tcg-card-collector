import gleam/list
import gleam/option.{None, Some}
import gleam/order
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/sort_spec.{
  ByCardType, ByCollectorNumber, ByColorIdentity, ByName, ByRarity, ByReleasedAt,
  BySetCode,
}
import shared/domain/card_key
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date

fn card(
  name: String,
  colors: String,
  card_type: attrs.CardType,
) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "set", collector_number: name)
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  let assert Ok(date) = release_date.parse("2020-01-01")
  let assert Ok(oracle) = oracle_id.new("o")
  attrs.PlannedCard(
    key:,
    name:,
    quantity: 1,
    released_at: Some(date),
    oracle_id: Some(oracle),
    rarity: Some(rarity.Common),
    color_identity: Some(color_identity),
    card_type: Some(card_type),
  )
}

// A card whose collection row the catalog couldn't identify: every attribute is
// absent, so it exercises the "missing sorts last" branches.
fn unknown_card(collector_number: String) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "set", collector_number:)
  attrs.PlannedCard(
    key:,
    name: "unknown",
    quantity: 1,
    released_at: None,
    oracle_id: None,
    rarity: None,
    color_identity: None,
    card_type: None,
  )
}

pub fn parses_sort_keys_test() {
  assert sort_spec.parse_sort_keys("color_identity,type,name")
    == Ok([ByColorIdentity, ByCardType, ByName])
  assert sort_spec.parse_sort_keys("") == Ok([])
}

pub fn parses_new_sort_keys_test() {
  assert sort_spec.parse_sort_keys("collector_number,rarity,released_at")
    == Ok([ByCollectorNumber, ByRarity, ByReleasedAt])
}

pub fn sort_keys_round_trip_test() {
  let keys = [
    ByColorIdentity,
    ByCardType,
    ByName,
    BySetCode,
    ByCollectorNumber,
    ByRarity,
    ByReleasedAt,
  ]
  assert sort_spec.parse_sort_keys(sort_spec.sort_keys_to_string(keys))
    == Ok(keys)
}

pub fn rejects_unknown_sort_key_test() {
  let assert Error(_) = sort_spec.parse_sort_keys("color_identity,power")
}

// Mono colors sort in WUBRG order (not alphabetically), then multicolor, then
// colorless last.
pub fn color_identity_ordering_test() {
  let cards = [
    card("e", "", attrs.Creature),
    card("d", "WU", attrs.Creature),
    card("c", "G", attrs.Creature),
    card("a", "W", attrs.Creature),
    card("b", "U", attrs.Creature),
  ]
  let sorted =
    list.sort(cards, fn(x, y) {
      sort_spec.compare_cards([ByColorIdentity], x, y)
    })
  let names = list.map(sorted, fn(c) { c.name })
  // a=W, b=U, c=G (mono in WUBRG order), d=WU (multicolor), e=colorless (last).
  assert names == ["a", "b", "c", "d", "e"]
}

pub fn secondary_sort_key_breaks_ties_test() {
  // Same color, different names -> name breaks the tie.
  let cards = [card("z", "R", attrs.Creature), card("a", "R", attrs.Creature)]
  let sorted =
    list.sort(cards, fn(x, y) {
      sort_spec.compare_cards([ByColorIdentity, ByName], x, y)
    })
  assert list.map(sorted, fn(c) { c.name }) == ["a", "z"]
}

// A card lacking a color identity sorts as colorless.
pub fn missing_color_sorts_last_test() {
  let red = card("red", "R", attrs.Creature)
  assert sort_spec.compare_cards([ByColorIdentity], red, unknown_card("x"))
    == order.Lt
}

// Collector numbers compare by their leading integer run numerically, so "2"
// precedes "10"; a shared run tie-breaks on the full string ("10" < "10a"); a
// value with a leading int sorts before a symbol-only one ("123a" < "★").
pub fn collector_number_total_order_test() {
  let cards =
    list.map(["★", "123a", "10a", "10", "2"], fn(cn) {
      card(cn, "R", attrs.Creature)
    })
  let sorted =
    list.sort(cards, fn(x, y) {
      sort_spec.compare_cards([ByCollectorNumber], x, y)
    })
  assert list.map(sorted, fn(c) { c.name }) == ["2", "10", "10a", "123a", "★"]
}

// Rarity ascending (common < ... < mythic), a card with no known rarity last.
pub fn rarity_ordering_puts_missing_last_test() {
  let common = card("common", "R", attrs.Creature)
  let mythic =
    attrs.PlannedCard(
      ..card("mythic", "R", attrs.Creature),
      rarity: Some(rarity.Mythic),
    )
  let cards = [unknown_card("x"), mythic, common]
  let sorted =
    list.sort(cards, fn(x, y) { sort_spec.compare_cards([ByRarity], x, y) })
  assert list.map(sorted, fn(c) { c.name }) == ["common", "mythic", "unknown"]
}

// released_at compares chronologically ascending; an unknown date sorts first.
pub fn released_at_ascending_unknown_first_test() {
  let assert Ok(old_date) = release_date.parse("1993-08-05")
  let old =
    attrs.PlannedCard(
      ..card("old", "R", attrs.Creature),
      released_at: Some(old_date),
    )
  let assert Ok(new_date) = release_date.parse("2020-01-01")
  let new =
    attrs.PlannedCard(
      ..card("new", "R", attrs.Creature),
      released_at: Some(new_date),
    )
  let cards = [new, old, unknown_card("x")]
  let sorted =
    list.sort(cards, fn(x, y) { sort_spec.compare_cards([ByReleasedAt], x, y) })
  // unknown_card has an empty released_at, so it sorts first.
  assert list.map(sorted, fn(c) { c.name }) == ["unknown", "old", "new"]
}

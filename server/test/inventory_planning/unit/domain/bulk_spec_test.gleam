import gleam/list
import gleam/option.{None, Some}
import gleam/order
import inventory_planning/domain/bulk_spec.{
  ByCardType, ByColorIdentity, ByName, BySetCode,
}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import shared/domain/card_key

fn card(
  name: String,
  colors: String,
  card_type: attrs.CardType,
) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "set", collector_number: name)
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  attrs.PlannedCard(
    key:,
    name:,
    quantity: 1,
    released_at: "2020-01-01",
    oracle_id: Some("o"),
    rarity: Some(attrs.Common),
    color_identity: Some(color_identity),
    card_type: Some(card_type),
  )
}

pub fn parses_sort_keys_test() {
  assert bulk_spec.parse_sort_keys("color_identity,type,name")
    == Ok([ByColorIdentity, ByCardType, ByName])
  assert bulk_spec.parse_sort_keys("") == Ok([])
}

pub fn sort_keys_round_trip_test() {
  let keys = [ByColorIdentity, ByCardType, ByName, BySetCode]
  assert bulk_spec.parse_sort_keys(bulk_spec.sort_keys_to_string(keys))
    == Ok(keys)
}

pub fn rejects_unknown_sort_key_test() {
  let assert Error(_) = bulk_spec.parse_sort_keys("color_identity,power")
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
      bulk_spec.compare_cards([ByColorIdentity], x, y)
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
      bulk_spec.compare_cards([ByColorIdentity, ByName], x, y)
    })
  assert list.map(sorted, fn(c) { c.name }) == ["a", "z"]
}

// A card lacking a color identity sorts as colorless.
pub fn missing_color_sorts_last_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "set", collector_number: "x")
  let unknown =
    attrs.PlannedCard(
      key:,
      name: "unknown",
      quantity: 1,
      released_at: "",
      oracle_id: None,
      rarity: None,
      color_identity: None,
      card_type: None,
    )
  let red = card("red", "R", attrs.Creature)
  assert bulk_spec.compare_cards([ByColorIdentity], red, unknown) == order.Lt
}

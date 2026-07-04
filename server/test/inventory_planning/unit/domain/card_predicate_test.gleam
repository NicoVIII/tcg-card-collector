import gleam/list
import gleam/option.{None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/card_predicate.{
  And, CardTypeIs, ColorIdentityIs, RarityAtLeast, RarityIn, SetCodeIn,
}
import shared/domain/card_key

fn card(
  set_code: String,
  rarity: attrs.Rarity,
  colors: String,
  card_type: attrs.CardType,
) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code:, collector_number: "1")
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  attrs.PlannedCard(
    key:,
    name: "Test",
    quantity: 1,
    released_at: "2020-01-01",
    oracle_id: Some("o1"),
    rarity: Some(rarity),
    color_identity: Some(color_identity),
    card_type: Some(card_type),
  )
}

pub fn parses_set_code_in_list_test() {
  assert card_predicate.parse("set_code in (grn, m19)")
    == Ok(SetCodeIn(["grn", "m19"]))
}

// The legacy single-equals form is accepted and normalizes to a one-element list
// so stored-rule migration is a data no-op.
pub fn parses_legacy_set_code_equals_test() {
  assert card_predicate.parse("set_code=GRN") == Ok(SetCodeIn(["grn"]))
}

pub fn parses_rarity_at_least_test() {
  assert card_predicate.parse("rarity >= rare") == Ok(RarityAtLeast(attrs.Rare))
}

pub fn parses_rarity_in_test() {
  assert card_predicate.parse("rarity in (common, uncommon)")
    == Ok(RarityIn([attrs.Common, attrs.Uncommon]))
}

pub fn parses_color_identity_test() {
  let assert Ok(wu) = attrs.parse_color_identity("WU")
  assert card_predicate.parse("color_identity = uw") == Ok(ColorIdentityIs(wu))
}

pub fn parses_type_test() {
  assert card_predicate.parse("type = land") == Ok(CardTypeIs(attrs.Land))
}

pub fn parses_conjunction_left_folded_test() {
  let assert Ok(pred) =
    card_predicate.parse(
      "set_code in (grn) and rarity >= rare and type = creature",
    )
  assert pred
    == And(
      And(SetCodeIn(["grn"]), RarityAtLeast(attrs.Rare)),
      CardTypeIs(attrs.Creature),
    )
}

pub fn rejects_empty_test() {
  assert card_predicate.parse("") == Error(card_predicate.EmptyPredicate)
}

pub fn rejects_unknown_attribute_test() {
  let assert Error(_) = card_predicate.parse("power >= 3")
}

pub fn rejects_unknown_rarity_test() {
  let assert Error(_) = card_predicate.parse("rarity >= legendary")
}

// to_string round-trips through parse for every predicate shape.
pub fn round_trips_through_parse_test() {
  let sources = [
    "set_code in (grn, m19)",
    "rarity >= rare",
    "rarity in (common, uncommon, mythic)",
    "color_identity = WU",
    "color_identity = colorless",
    "type = planeswalker",
    "set_code in (grn) and rarity >= rare and type = creature",
  ]
  assert list.all(sources, fn(src) {
    let assert Ok(parsed) = card_predicate.parse(src)
    card_predicate.parse(card_predicate.to_string(parsed)) == Ok(parsed)
  })
}

pub fn matches_set_code_test() {
  let assert Ok(pred) = card_predicate.parse("set_code in (grn)")
  assert card_predicate.matches(
    pred,
    card("grn", attrs.Rare, "R", attrs.Creature),
  )
  assert !card_predicate.matches(
    pred,
    card("m19", attrs.Rare, "R", attrs.Creature),
  )
}

// special/bonus are below rare, so `rarity >= rare` excludes them.
pub fn rarity_at_least_excludes_special_and_bonus_test() {
  let assert Ok(pred) = card_predicate.parse("rarity >= rare")
  assert card_predicate.matches(
    pred,
    card("x", attrs.Rare, "R", attrs.Creature),
  )
  assert card_predicate.matches(
    pred,
    card("x", attrs.Mythic, "R", attrs.Creature),
  )
  assert !card_predicate.matches(
    pred,
    card("x", attrs.Special, "R", attrs.Creature),
  )
  assert !card_predicate.matches(
    pred,
    card("x", attrs.Bonus, "R", attrs.Creature),
  )
}

// A clause on an attribute the card lacks is False.
pub fn missing_attribute_matches_false_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "x", collector_number: "1")
  let bare =
    attrs.PlannedCard(
      key:,
      name: "Test",
      quantity: 1,
      released_at: "",
      oracle_id: None,
      rarity: None,
      color_identity: None,
      card_type: None,
    )
  let assert Ok(pred) = card_predicate.parse("rarity >= rare")
  assert !card_predicate.matches(pred, bare)
}

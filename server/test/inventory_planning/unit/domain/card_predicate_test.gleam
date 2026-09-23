import gleam/list
import gleam/option.{None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/card_predicate.{
  And, CardTypeIs, CardTypeIsNot, ColorIdentityIs, ColorIdentityIsNot, FinishIn,
  FinishIsNot, RarityAtLeast, RarityIn, SetCodeIn, SetCodeIsNot,
}
import shared/domain/card_key
import shared/domain/finish
import shared/domain/language
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date

fn card(
  set_code: String,
  rarity_value: rarity.Rarity,
  colors: String,
  card_type: attrs.CardType,
) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code:, collector_number: "1")
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  let assert Ok(date) = release_date.parse("2020-01-01")
  let assert Ok(oracle) = oracle_id.new("o1")
  attrs.PlannedCard(
    key:,
    name: "Test",
    quantity: 1,
    finish: finish.Nonfoil,
    language: language.En,
    released_at: Some(date),
    oracle_id: Some(oracle),
    rarity: Some(rarity_value),
    color_identity: Some(color_identity),
    card_type: Some(card_type),
    cmc: None,
  )
}

fn bare_card() -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "x", collector_number: "1")
  attrs.PlannedCard(
    key:,
    name: "Test",
    quantity: 1,
    finish: finish.Nonfoil,
    language: language.En,
    released_at: None,
    oracle_id: None,
    rarity: None,
    color_identity: None,
    card_type: None,
    cmc: None,
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
  assert card_predicate.parse("rarity >= rare")
    == Ok(RarityAtLeast(rarity.Rare))
}

pub fn parses_rarity_in_test() {
  assert card_predicate.parse("rarity in (common, uncommon)")
    == Ok(RarityIn([rarity.Common, rarity.Uncommon]))
}

pub fn parses_color_identity_test() {
  let assert Ok(wu) = attrs.parse_color_identity("WU")
  assert card_predicate.parse("color_identity = uw") == Ok(ColorIdentityIs(wu))
}

pub fn parses_type_test() {
  assert card_predicate.parse("type = land") == Ok(CardTypeIs(attrs.Land))
}

pub fn parses_finish_equals_test() {
  assert card_predicate.parse("finish = FOIL") == Ok(FinishIn([finish.Foil]))
}

pub fn parses_finish_in_test() {
  assert card_predicate.parse("finish in (foil, etched)")
    == Ok(FinishIn([finish.Foil, finish.Etched]))
}

pub fn rejects_unknown_finish_test() {
  let assert Error(_) = card_predicate.parse("finish = shiny")
}

pub fn parses_set_code_not_eq_test() {
  assert card_predicate.parse("set_code != GRN") == Ok(SetCodeIsNot("grn"))
}

pub fn parses_color_identity_not_eq_test() {
  let assert Ok(wu) = attrs.parse_color_identity("WU")
  assert card_predicate.parse("color_identity != uw")
    == Ok(ColorIdentityIsNot(wu))
}

pub fn parses_type_not_eq_test() {
  assert card_predicate.parse("type != land") == Ok(CardTypeIsNot(attrs.Land))
}

pub fn parses_finish_not_eq_test() {
  assert card_predicate.parse("finish != foil") == Ok(FinishIsNot(finish.Foil))
}

// != has no meaning on rarity, which only takes >=.
pub fn rejects_not_eq_on_rarity_test() {
  let assert Error(_) = card_predicate.parse("rarity != rare")
}

// A bare "!" (no following "=") is malformed, mirroring the ">" precedent.
pub fn rejects_bare_bang_test() {
  let assert Error(_) = card_predicate.parse("set_code ! grn")
}

pub fn parses_conjunction_left_folded_test() {
  let assert Ok(pred) =
    card_predicate.parse(
      "set_code in (grn) and rarity >= rare and type = creature",
    )
  assert pred
    == And(
      And(SetCodeIn(["grn"]), RarityAtLeast(rarity.Rare)),
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
    "finish = etched",
    "finish in (foil, etched)",
    "set_code != grn",
    "color_identity != WU",
    "type != land",
    "finish != foil",
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
    card("grn", rarity.Rare, "R", attrs.Creature),
  )
  assert !card_predicate.matches(
    pred,
    card("m19", rarity.Rare, "R", attrs.Creature),
  )
}

// special/bonus are below rare, so `rarity >= rare` excludes them.
pub fn rarity_at_least_excludes_special_and_bonus_test() {
  let assert Ok(pred) = card_predicate.parse("rarity >= rare")
  assert card_predicate.matches(
    pred,
    card("x", rarity.Rare, "R", attrs.Creature),
  )
  assert card_predicate.matches(
    pred,
    card("x", rarity.Mythic, "R", attrs.Creature),
  )
  assert !card_predicate.matches(
    pred,
    card("x", rarity.Special, "R", attrs.Creature),
  )
  assert !card_predicate.matches(
    pred,
    card("x", rarity.Bonus, "R", attrs.Creature),
  )
}

pub fn matches_finish_test() {
  let assert Ok(pred) = card_predicate.parse("finish in (foil, etched)")
  let foil_card =
    attrs.PlannedCard(
      ..card("x", rarity.Rare, "R", attrs.Creature),
      finish: finish.Foil,
    )
  let nonfoil_card = card("x", rarity.Rare, "R", attrs.Creature)
  assert card_predicate.matches(pred, foil_card)
  assert !card_predicate.matches(pred, nonfoil_card)
}

// A clause on an attribute the card lacks is False.
pub fn missing_attribute_matches_false_test() {
  let assert Ok(pred) = card_predicate.parse("rarity >= rare")
  assert !card_predicate.matches(pred, bare_card())
}

pub fn matches_set_code_not_eq_test() {
  let assert Ok(pred) = card_predicate.parse("set_code != grn")
  assert !card_predicate.matches(
    pred,
    card("grn", rarity.Rare, "R", attrs.Creature),
  )
  assert card_predicate.matches(
    pred,
    card("m19", rarity.Rare, "R", attrs.Creature),
  )
}

pub fn matches_finish_not_eq_test() {
  let assert Ok(pred) = card_predicate.parse("finish != foil")
  let foil_card =
    attrs.PlannedCard(
      ..card("x", rarity.Rare, "R", attrs.Creature),
      finish: finish.Foil,
    )
  assert !card_predicate.matches(pred, foil_card)
  assert card_predicate.matches(
    pred,
    card("x", rarity.Rare, "R", attrs.Creature),
  )
}

// Negation doesn't flip the unknown-enrichment case: a card the catalog
// doesn't know still fails != the same way it fails =.
pub fn negated_enrichment_clause_matches_false_when_unknown_test() {
  let assert Ok(color_pred) = card_predicate.parse("color_identity != WU")
  let assert Ok(type_pred) = card_predicate.parse("type != land")
  assert !card_predicate.matches(color_pred, bare_card())
  assert !card_predicate.matches(type_pred, bare_card())
}

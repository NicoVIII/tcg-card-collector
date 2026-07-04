import gleam/option.{None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/location_target.{Fixed, Template}
import shared/domain/card_key

fn card_with_color(colors: String) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "grn", collector_number: "1")
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  attrs.PlannedCard(
    key:,
    name: "Test",
    quantity: 1,
    released_at: "2018-10-05",
    oracle_id: Some("o1"),
    rarity: Some(attrs.Rare),
    color_identity: Some(color_identity),
    card_type: Some(attrs.Creature),
  )
}

pub fn parses_fixed_when_no_placeholder_test() {
  assert location_target.parse("Bulk") == Fixed("Bulk")
}

pub fn parses_template_test() {
  assert location_target.parse("binder {color_identity}")
    == Template("binder ", location_target.ColorIdentityAttribute, "")
}

pub fn template_round_trips_test() {
  let src = "set binder {set_code} shelf"
  assert location_target.to_string(location_target.parse(src)) == src
}

pub fn renders_fixed_test() {
  assert location_target.render(Fixed("Bulk"), card_with_color("R"))
    == Some("Bulk")
}

pub fn renders_set_code_template_test() {
  let target = location_target.parse("set binder {set_code}")
  assert location_target.render(target, card_with_color("R"))
    == Some("set binder grn")
}

pub fn renders_color_identity_template_test() {
  let target = location_target.parse("binder {color_identity}")
  assert location_target.render(target, card_with_color("WU"))
    == Some("binder WU")
}

// A template on an attribute the card lacks renders to None — the rule doesn't
// claim the card.
pub fn renders_none_when_attribute_missing_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "grn", collector_number: "1")
  let no_color =
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
  let target = location_target.parse("binder {color_identity}")
  assert location_target.render(target, no_color) == None
  // But a set_code template still renders, since the key is always present.
  let set_target = location_target.parse("set binder {set_code}")
  assert location_target.render(set_target, no_color) == Some("set binder grn")
}

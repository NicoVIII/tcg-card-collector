import gleam/list
import inventory_planning/domain/card_attributes as attrs

// common < uncommon < special < bonus < rare < mythic
pub fn rarity_total_order_test() {
  let ascending = [
    attrs.Common,
    attrs.Uncommon,
    attrs.Special,
    attrs.Bonus,
    attrs.Rare,
    attrs.Mythic,
  ]
  let ranks = list.map(ascending, attrs.rarity_rank)
  assert ranks == [0, 1, 2, 3, 4, 5]
  assert attrs.rarity_at_least(attrs.Rare, attrs.Rare)
  assert !attrs.rarity_at_least(attrs.Bonus, attrs.Rare)
}

pub fn rarity_parse_round_trip_test() {
  let all = [
    attrs.Common,
    attrs.Uncommon,
    attrs.Special,
    attrs.Bonus,
    attrs.Rare,
    attrs.Mythic,
  ]
  assert list.all(all, fn(r) {
    attrs.parse_rarity(attrs.rarity_to_string(r)) == Ok(r)
  })
}

// Color identity is canonical: letter order doesn't matter, empty is colorless.
pub fn color_identity_canonical_test() {
  assert attrs.parse_color_identity("UW") == attrs.parse_color_identity("WU")
  assert attrs.parse_color_identity("") == Ok(attrs.colorless())
  assert attrs.parse_color_identity("colorless") == Ok(attrs.colorless())
}

pub fn color_identity_letters_canonical_order_test() {
  let assert Ok(brg) = attrs.parse_color_identity("GRB")
  // WUBRG order: B, R, G
  assert attrs.color_identity_letters(brg) == "BRG"
}

pub fn color_identity_token_round_trips_test() {
  let assert Ok(wu) = attrs.parse_color_identity("WU")
  assert attrs.parse_color_identity(attrs.color_identity_token(wu)) == Ok(wu)
  assert attrs.color_identity_token(attrs.colorless()) == "colorless"
}

pub fn rejects_bad_color_letter_test() {
  let assert Error(_) = attrs.parse_color_identity("WX")
}

// Type line reduces to the highest-priority type present.
pub fn card_type_priority_test() {
  assert attrs.card_type_from_type_line("Legendary Creature — Elf")
    == attrs.Creature
  // Land beats Creature when both appear.
  assert attrs.card_type_from_type_line("Land Creature — Dryad Arbor")
    == attrs.Land
  assert attrs.card_type_from_type_line("Artifact — Equipment")
    == attrs.Artifact
  assert attrs.card_type_from_type_line("Legendary Planeswalker — Jace")
    == attrs.Planeswalker
  assert attrs.card_type_from_type_line("Tribal Instant — Arcane")
    == attrs.Instant
  assert attrs.card_type_from_type_line("Conspiracy") == attrs.Other
}

pub fn card_type_parse_round_trip_test() {
  let all = [
    attrs.Land,
    attrs.Creature,
    attrs.Artifact,
    attrs.Enchantment,
    attrs.Planeswalker,
    attrs.Battle,
    attrs.Instant,
    attrs.Sorcery,
    attrs.Other,
  ]
  assert list.all(all, fn(t) {
    attrs.parse_card_type(attrs.card_type_to_string(t)) == Ok(t)
  })
}

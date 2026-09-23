import gleam/list
import gleam/option.{None, Some}
import gleam/order
import inventory_planning/domain/card_attributes as attrs
import shared/domain/color_identity
import shared/domain/finish
import shared/domain/language
import shared/domain/mana_value
import shared/domain/rarity

// common < uncommon < special < bonus < rare < mythic
pub fn rarity_total_order_test() {
  let ascending = [
    rarity.Common,
    rarity.Uncommon,
    rarity.Special,
    rarity.Bonus,
    rarity.Rare,
    rarity.Mythic,
  ]
  let ranks = list.map(ascending, attrs.rarity_rank)
  assert ranks == [0, 1, 2, 3, 4, 5]
  assert attrs.rarity_at_least(rarity.Rare, rarity.Rare)
  assert !attrs.rarity_at_least(rarity.Bonus, rarity.Rare)
}

pub fn rarity_parse_round_trip_test() {
  let all = [
    rarity.Common,
    rarity.Uncommon,
    rarity.Special,
    rarity.Bonus,
    rarity.Rare,
    rarity.Mythic,
  ]
  assert list.all(all, fn(r) {
    attrs.parse_rarity(rarity.to_string(r)) == Ok(r)
  })
}

// Color identity is canonical: letter order doesn't matter, empty is colorless.
pub fn color_identity_canonical_test() {
  assert attrs.parse_color_identity("UW") == attrs.parse_color_identity("WU")
  assert attrs.parse_color_identity("") == Ok(color_identity.colorless())
  assert attrs.parse_color_identity("colorless")
    == Ok(color_identity.colorless())
}

pub fn color_identity_letters_canonical_order_test() {
  let assert Ok(brg) = attrs.parse_color_identity("GRB")
  // WUBRG order: B, R, G
  assert color_identity.letters(brg) == "BRG"
}

pub fn color_identity_token_round_trips_test() {
  let assert Ok(wu) = attrs.parse_color_identity("WU")
  assert attrs.parse_color_identity(attrs.color_identity_token(wu)) == Ok(wu)
  assert attrs.color_identity_token(color_identity.colorless()) == "colorless"
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

// Supertypes are a positional prefix, not a substring test: they stop at the
// first word that isn't one of CR 205.4a's five, so a subtype after the em
// dash never gets swept in.
pub fn supertypes_prefix_walk_test() {
  assert attrs.supertypes_from_type_line("Basic Land — Plains") == [attrs.Basic]
  // Wastes: no subtype after the type.
  assert attrs.supertypes_from_type_line("Basic Land") == [attrs.Basic]
  // Snow-Covered Wastes: two supertypes, no subtype.
  assert attrs.supertypes_from_type_line("Basic Snow Land")
    == [attrs.Basic, attrs.Snow]
  // Snow-Covered Plains: two supertypes, with a subtype.
  assert attrs.supertypes_from_type_line("Basic Snow Land — Plains")
    == [attrs.Basic, attrs.Snow]
  assert attrs.supertypes_from_type_line("Legendary Creature — Elf")
    == [attrs.Legendary]
  // A nonbasic land carries no supertype.
  assert attrs.supertypes_from_type_line("Land — Gate") == []
  assert attrs.supertypes_from_type_line("Creature — Bear") == []
  assert attrs.supertypes_from_type_line("") == []
}

pub fn supertype_parse_round_trip_test() {
  let all = [
    attrs.Legendary,
    attrs.Basic,
    attrs.Snow,
    attrs.World,
    attrs.Ongoing,
  ]
  assert list.all(all, fn(s) {
    attrs.parse_supertype(attrs.supertype_to_string(s)) == Ok(s)
  })
}

pub fn supertype_parse_trims_and_lowercases_test() {
  assert attrs.parse_supertype("  BASIC  ") == Ok(attrs.Basic)
}

pub fn supertype_parse_rejects_unknown_test() {
  let assert Error(_) = attrs.parse_supertype("mythic")
}

// nonfoil < foil < etched
pub fn finish_total_order_test() {
  let ascending = [finish.Nonfoil, finish.Foil, finish.Etched]
  let ranks = list.map(ascending, attrs.finish_rank)
  assert ranks == [0, 1, 2]
}

// English sorts before every other language; the rest compare by code.
pub fn language_compare_en_first_test() {
  assert attrs.compare_language_en_first(language.En, language.De) == order.Lt
  assert attrs.compare_language_en_first(language.De, language.En) == order.Gt
  assert attrs.compare_language_en_first(language.En, language.En) == order.Eq
  assert attrs.compare_language_en_first(language.De, language.Fr) == order.Lt
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

pub fn finish_parse_round_trip_test() {
  let all = [finish.Nonfoil, finish.Foil, finish.Etched]
  assert list.all(all, fn(f) {
    attrs.parse_finish(finish.to_string(f)) == Ok(f)
  })
}

// cmc ascending; unknown sorts last (opposite of compare_release_earliest_first,
// which sorts unknown first) — 0 is a real value, not a stand-in for unknown.
pub fn cmc_compare_lowest_first_unknown_last_test() {
  let assert Ok(zero) = mana_value.from_float(0.0)
  let assert Ok(four) = mana_value.from_float(4.0)
  assert attrs.compare_cmc_lowest_first(Some(zero), Some(four)) == order.Lt
  assert attrs.compare_cmc_lowest_first(Some(four), Some(zero)) == order.Gt
  assert attrs.compare_cmc_lowest_first(Some(zero), None) == order.Lt
  assert attrs.compare_cmc_lowest_first(None, Some(zero)) == order.Gt
  assert attrs.compare_cmc_lowest_first(None, None) == order.Eq
}

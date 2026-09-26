import gleam/list
import gleam/option.{None, Some}
import gleam/order
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/sort_spec.{
  ByCardType, ByCollectorNumber, ByColorIdentity, ByLanguage, ByManaValue,
  ByName, ByRarity, ByReleasedAt, BySetCode,
}
import shared/domain/card_key
import shared/domain/finish
import shared/domain/language
import shared/domain/mana_value
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
  let assert Ok(cmc) = mana_value.from_float(2.0)
  attrs.PlannedCard(
    key:,
    name:,
    quantity: 1,
    finish: finish.Nonfoil,
    language: language.En,
    released_at: Some(date),
    oracle_id: Some(oracle),
    rarity: Some(rarity.Common),
    color_identity: Some(color_identity),
    card_type: Some(card_type),
    supertypes: Some([]),
    cmc: Some(cmc),
    is_token: Some(False),
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
    finish: finish.Nonfoil,
    language: language.En,
    released_at: None,
    oracle_id: None,
    rarity: None,
    color_identity: None,
    card_type: None,
    supertypes: None,
    cmc: None,
    is_token: None,
  )
}

pub fn parses_sort_keys_test() {
  assert sort_spec.parse_sort_keys("color_identity,type,name")
    == Ok([ByColorIdentity, ByCardType, ByName])
  assert sort_spec.parse_sort_keys("") == Ok([])
}

pub fn parses_new_sort_keys_test() {
  assert sort_spec.parse_sort_keys("collector_number,rarity,released_at,cmc")
    == Ok([ByCollectorNumber, ByRarity, ByReleasedAt, ByManaValue])
}

pub fn parses_language_sort_key_test() {
  assert sort_spec.parse_sort_keys("language") == Ok([ByLanguage])
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
    ByManaValue,
    ByLanguage,
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

// The full 32-color-identity order (#103): mono in WUBRG order, then
// multicolor in WOTC's printed order — allied pairs, enemy pairs, shards,
// wedges, four-color (each "missing one color"), five-color — then colorless
// last. Each string is the identity spelled the way WOTC prints it (e.g. the
// enemy pair "RW", the shard "GWU"); parsing canonicalizes it.
pub fn color_identity_full_ordering_test() {
  let expected = [
    "W", "U", "B", "R", "G", "WU", "UB", "BR", "RG", "GW", "WB", "UR", "BG",
    "RW", "UG", "WUB", "UBR", "BRG", "RGW", "GWU", "WBG", "WUR", "UBG", "BRW",
    "RGU", "WUBR", "UBRG", "BRGW", "RGWU", "GWUB", "WUBRG", "colorless",
  ]
  let cards =
    expected
    |> list.map(fn(colors) { card(colors, colors, attrs.Creature) })
    // Reverse so the sort is actually exercised, not a pass-through.
    |> list.reverse
  let sorted =
    list.sort(cards, fn(x, y) {
      sort_spec.compare_cards([ByColorIdentity], x, y)
    })
  assert list.map(sorted, fn(c) { c.name }) == expected
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

// cmc compares ascending; an unknown mana value sorts last (the opposite of
// released_at above), and a real 0 (a land) sorts before every known cost,
// never confused with unknown.
pub fn cmc_ascending_unknown_last_test() {
  let assert Ok(zero) = mana_value.from_float(0.0)
  let land = attrs.PlannedCard(..card("land", "R", attrs.Land), cmc: Some(zero))
  let assert Ok(four) = mana_value.from_float(4.0)
  let bomb =
    attrs.PlannedCard(..card("bomb", "R", attrs.Creature), cmc: Some(four))
  let cards = [bomb, unknown_card("x"), land]
  let sorted =
    list.sort(cards, fn(x, y) { sort_spec.compare_cards([ByManaValue], x, y) })
  assert list.map(sorted, fn(c) { c.name }) == ["land", "bomb", "unknown"]
}

// A cmc tie falls through to the next sort key.
pub fn cmc_tie_breaks_on_next_key_test() {
  let z = card("z", "R", attrs.Creature)
  let a = card("a", "R", attrs.Creature)
  let sorted =
    list.sort([z, a], fn(x, y) {
      sort_spec.compare_cards([ByManaValue, ByName], x, y)
    })
  assert list.map(sorted, fn(c) { c.name }) == ["a", "z"]
}

// language sorts English first, then the rest by code (#112) — the same
// policy as the claim order's language step (ADR 0013), reused here as the
// sort key's comparator.
pub fn language_ordering_english_first_then_by_code_test() {
  let ja =
    attrs.PlannedCard(..card("ja", "R", attrs.Creature), language: language.Ja)
  let de =
    attrs.PlannedCard(..card("de", "R", attrs.Creature), language: language.De)
  let en =
    attrs.PlannedCard(..card("en", "R", attrs.Creature), language: language.En)
  let sorted =
    list.sort([ja, de, en], fn(x, y) {
      sort_spec.compare_cards([ByLanguage], x, y)
    })
  assert list.map(sorted, fn(c) { c.name }) == ["en", "de", "ja"]
}

// --- category (#138) --------------------------------------------------------
//
// Each case doubles as the coarsening/contiguity contract sort_section relies
// on: a known card's category is its sort value's own display spelling, and
// an unknown value maps to whichever category shares that key's "unknown
// sorts last/first" rank (compare_cards above), so equal-category cards never
// sort apart.

pub fn category_color_identity_known_and_unknown_test() {
  assert sort_spec.category(ByColorIdentity, card("red", "R", attrs.Creature))
    == Some("R")
  // Ranks equal to real colorless (color_rank's fallback) — same label.
  assert sort_spec.category(ByColorIdentity, unknown_card("x"))
    == Some("Colorless")
}

pub fn category_card_type_known_and_unknown_test() {
  assert sort_spec.category(ByCardType, card("c", "R", attrs.Creature))
    == Some("creature")
  assert sort_spec.category(ByCardType, unknown_card("x")) == Some("other")
}

pub fn category_name_is_first_grapheme_test() {
  assert sort_spec.category(ByName, card("Zebra", "R", attrs.Creature))
    == Some("Z")
  assert sort_spec.category(ByName, card("apple", "R", attrs.Creature))
    == Some("a")
}

pub fn category_set_code_test() {
  assert sort_spec.category(BySetCode, card("x", "R", attrs.Creature))
    == Some("set")
}

// collector_number is unique per printing — grouping by it would never
// merge anything, so it yields no category at all.
pub fn category_collector_number_has_none_test() {
  assert sort_spec.category(ByCollectorNumber, card("x", "R", attrs.Creature))
    == None
}

pub fn category_rarity_known_and_unknown_test() {
  assert sort_spec.category(ByRarity, card("c", "R", attrs.Creature))
    == Some("common")
  assert sort_spec.category(ByRarity, unknown_card("x")) == Some("unknown")
}

pub fn category_released_at_is_year_test() {
  let assert Ok(date) = release_date.parse("1999-08-05")
  let old =
    attrs.PlannedCard(..card("c", "R", attrs.Creature), released_at: Some(date))
  assert sort_spec.category(ByReleasedAt, old) == Some("1999")
  assert sort_spec.category(ByReleasedAt, unknown_card("x")) == Some("unknown")
}

pub fn category_cmc_drops_trailing_zero_but_keeps_real_fractions_test() {
  let assert Ok(three) = mana_value.from_float(3.0)
  let whole =
    attrs.PlannedCard(..card("c", "R", attrs.Creature), cmc: Some(three))
  assert sort_spec.category(ByManaValue, whole) == Some("3")

  let assert Ok(half) = mana_value.from_float(0.5)
  let fractional =
    attrs.PlannedCard(..card("c", "R", attrs.Creature), cmc: Some(half))
  assert sort_spec.category(ByManaValue, fractional) == Some("0.5")

  assert sort_spec.category(ByManaValue, unknown_card("x")) == Some("unknown")
}

pub fn category_language_test() {
  let de =
    attrs.PlannedCard(..card("c", "R", attrs.Creature), language: language.De)
  assert sort_spec.category(ByLanguage, de) == Some("de")
}

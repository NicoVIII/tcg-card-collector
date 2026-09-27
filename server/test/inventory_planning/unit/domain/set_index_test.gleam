import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/set_index.{SetMeta}
import shared/domain/card_key
import shared/domain/finish
import shared/domain/language
import shared/domain/release_date

fn index(entries: List(#(String, Option(String)))) -> set_index.SetIndex {
  entries
  |> dict.from_list
  |> dict.map_values(fn(_code, parent) {
    SetMeta(released_at: None, parent_set_code: parent)
  })
}

// A child set resolves to its parent as the family root.
pub fn child_resolves_to_parent_test() {
  let sets = index([#("tgrn", Some("grn")), #("grn", None)])
  assert set_index.family_root(sets, "tgrn") == "grn"
}

// A grandchild walks the parent chain transitively to the top.
pub fn grandchild_resolves_transitively_test() {
  let sets =
    index([#("ggg", Some("child")), #("child", Some("root")), #("root", None)])
  assert set_index.family_root(sets, "ggg") == "root"
}

// A set not in the index is its own family root.
pub fn unknown_set_is_own_root_test() {
  assert set_index.family_root(dict.new(), "xyz") == "xyz"
}

// A set with no parent is its own family root.
pub fn root_set_is_own_root_test() {
  let sets = index([#("grn", None)])
  assert set_index.family_root(sets, "grn") == "grn"
}

// A corrupt parent cycle (a↔b) terminates instead of looping forever, and does
// so deterministically (same input → same output).
pub fn parent_cycle_terminates_deterministically_test() {
  let sets = index([#("a", Some("b")), #("b", Some("a"))])
  let first = set_index.family_root(sets, "a")
  assert first == set_index.family_root(sets, "a")
}

// release_date reads the indexed date, and is None for an unknown set.
pub fn release_date_reads_index_and_defaults_none_test() {
  let assert Ok(date) = release_date.parse("2018-10-05")
  let sets =
    dict.from_list([
      #("grn", SetMeta(released_at: Some(date), parent_set_code: None)),
    ])
  assert set_index.release_date(sets, "grn") == Some(date)
  assert set_index.release_date(sets, "xyz") == None
}

// A minimal PlannedCard for the release_date_or_earliest / stamp_set_release
// tests below — only key and released_at matter to them.
fn card(
  set_code: String,
  collector_number: String,
  released_at: Option(release_date.ReleaseDate),
) -> PlannedCard {
  let assert Ok(key) = card_key.from_user_input(set_code:, collector_number:)
  attrs.PlannedCard(
    key:,
    name: "",
    quantity: 1,
    finish: finish.Nonfoil,
    language: language.En,
    released_at:,
    set_released_at: None,
    oracle_id: None,
    rarity: None,
    color_identity: None,
    card_type: None,
    supertypes: None,
    cmc: None,
    is_token: None,
  )
}

// The catalog date wins even when card-level dates disagree with it.
pub fn release_date_or_earliest_prefers_catalog_date_test() {
  let assert Ok(catalog_date) = release_date.parse("2018-10-05")
  let assert Ok(card_date) = release_date.parse("2020-01-01")
  let sets =
    dict.from_list([
      #("grn", SetMeta(released_at: Some(catalog_date), parent_set_code: None)),
    ])
  assert set_index.release_date_or_earliest(sets, "grn", [Some(card_date)])
    == Some(catalog_date)
}

// Without a catalog date, the earliest known card date wins — not the first
// in the list, and not the latest.
pub fn release_date_or_earliest_falls_back_to_minimum_card_date_test() {
  let assert Ok(early) = release_date.parse("2015-01-01")
  let assert Ok(late) = release_date.parse("2018-10-05")
  assert set_index.release_date_or_earliest(dict.new(), "grn", [
      Some(late),
      Some(early),
    ])
    == Some(early)
}

// Neither a catalog date nor any card date: None (sorts first, same posture
// as released_at's own unknowns).
pub fn release_date_or_earliest_is_none_without_any_date_test() {
  assert set_index.release_date_or_earliest(dict.new(), "grn", [None, None])
    == None
}

// Every card of a set gets the same resolved date, even when their own
// released_at values differ (promos, Secret Lair drops) — the set never
// splits under set_released_at.
pub fn stamp_set_release_gives_every_card_of_a_set_the_same_date_test() {
  let assert Ok(early) = release_date.parse("2015-01-01")
  let assert Ok(late) = release_date.parse("2018-10-05")
  let cards = [
    card("grn", "1", Some(late)),
    card("grn", "2", Some(early)),
    card("grn", "3", None),
  ]
  let stamped = set_index.stamp_set_release(dict.new(), cards)
  assert list.all(stamped, fn(c) { c.set_released_at == Some(early) })
}

// Two different sets are resolved independently.
pub fn stamp_set_release_resolves_each_set_independently_test() {
  let assert Ok(grn_date) = release_date.parse("2018-10-05")
  let assert Ok(dom_date) = release_date.parse("2018-04-27")
  let sets =
    dict.from_list([
      #("grn", SetMeta(released_at: Some(grn_date), parent_set_code: None)),
      #("dom", SetMeta(released_at: Some(dom_date), parent_set_code: None)),
    ])
  let cards = [card("grn", "1", None), card("dom", "1", None)]
  let stamped = set_index.stamp_set_release(sets, cards)
  let assert [grn_card, dom_card] = stamped
  assert grn_card.set_released_at == Some(grn_date)
  assert dom_card.set_released_at == Some(dom_date)
}

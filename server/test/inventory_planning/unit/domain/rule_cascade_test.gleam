import gleam/list
import gleam/option.{None, Some}
import inventory_planning/domain/bulk_spec
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_target
import inventory_planning/domain/rule_cascade.{
  type CascadeRule, type RuleCascade, CascadeRule, RuleCascade,
}
import shared/domain/card_key

fn card(
  set_code: String,
  collector_number: String,
  name: String,
  quantity: Int,
  released_at: String,
  oracle_id: String,
  rarity: attrs.Rarity,
  colors: String,
) -> PlannedCard {
  let assert Ok(key) = card_key.from_user_input(set_code:, collector_number:)
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  attrs.PlannedCard(
    key:,
    name:,
    quantity:,
    released_at:,
    oracle_id: Some(oracle_id),
    rarity: Some(rarity),
    color_identity: Some(color_identity),
    card_type: Some(attrs.Creature),
  )
}

fn rule(
  id: String,
  position: Int,
  selector: copy_selector.CopySelector,
  predicate_src: String,
  target_src: String,
) -> CascadeRule {
  let assert Ok(predicate) = card_predicate.parse(predicate_src)
  CascadeRule(
    id:,
    position:,
    selector:,
    predicate:,
    target: location_target.parse(target_src),
  )
}

// The owner's four-tier waterfall: set binders, then rare color binders, then
// common/uncommon color boxes, then bulk.
fn owner_cascade() -> RuleCascade {
  RuleCascade(
    rules: [
      rule(
        "r1",
        1,
        copy_selector.FirstCopyPerPrinting,
        "set_code in (grn)",
        "set binder {set_code}",
      ),
      rule(
        "r2",
        2,
        copy_selector.FirstCopyPerOracle,
        "rarity >= rare",
        "binder {color_identity}",
      ),
      rule(
        "r3",
        3,
        copy_selector.FirstCopyPerOracle,
        "rarity in (common, uncommon)",
        "box {color_identity}",
      ),
    ],
    bulk: bulk_spec.BulkSpec("Bulk", [
      bulk_spec.ByColorIdentity,
      bulk_spec.ByCardType,
      bulk_spec.ByName,
    ]),
  )
}

fn find_bucket(
  buckets: List(rule_cascade.LocationBucket),
  name: String,
) -> rule_cascade.LocationBucket {
  let assert Ok(bucket) = list.find(buckets, fn(b) { b.location_name == name })
  bucket
}

fn conservation_holds(cards: List(PlannedCard)) -> Bool {
  let buckets = rule_cascade.project(owner_cascade(), cards)
  let placed = list.fold(buckets, 0, fn(sum, b) { sum + b.total_quantity })
  let owned = list.fold(cards, 0, fn(sum, c) { sum + c.quantity })
  placed == owned
}

// A single 4-of rare from a set binder set splits 1 / 1 / 2 across the set
// binder, the color binder, and bulk.
pub fn four_of_rare_splits_across_tiers_test() {
  let cards = [
    card("grn", "173", "Guildmage", 4, "2018-10-05", "o1", attrs.Rare, "R"),
  ]
  let buckets = rule_cascade.project(owner_cascade(), cards)

  assert list.length(buckets) == 3

  let set_binder = find_bucket(buckets, "set binder grn")
  assert set_binder.total_quantity == 1
  assert set_binder.rule_id == Some("r1")

  let color_binder = find_bucket(buckets, "binder R")
  assert color_binder.total_quantity == 1
  assert color_binder.rule_id == Some("r2")

  let bulk = find_bucket(buckets, "Bulk")
  assert bulk.total_quantity == 2
  assert bulk.rule_id == None
}

// Buckets appear in rule-position order, bulk last.
pub fn buckets_ordered_by_position_then_bulk_test() {
  let cards = [
    card("grn", "173", "Guildmage", 4, "2018-10-05", "o1", attrs.Rare, "R"),
  ]
  let names =
    rule_cascade.project(owner_cascade(), cards)
    |> list.map(fn(b) { b.location_name })
  assert names == ["set binder grn", "binder R", "Bulk"]
}

// Quantity is conserved: every owned copy lands in exactly one bucket.
pub fn quantity_conserved_test() {
  let cards = [
    card("grn", "173", "Guildmage", 4, "2018-10-05", "o1", attrs.Rare, "R"),
    card("m19", "5", "Common Card", 3, "2018-07-13", "o2", attrs.Common, "U"),
    card(
      "mh1",
      "42",
      "Uncommon Card",
      2,
      "2019-06-14",
      "o3",
      attrs.Uncommon,
      "",
    ),
    card("war", "99", "Mythic Card", 1, "2019-05-03", "o4", attrs.Mythic, "WB"),
  ]
  assert conservation_holds(cards)
}

// A first-copy-per-oracle rule claims at most one copy per oracle identity, even
// across multiple printings of that oracle.
pub fn first_copy_per_oracle_dedupes_printings_test() {
  // Two printings of the same rare oracle, neither in a set-binder set, so the
  // set-binder rule doesn't fire. The color-binder rule (per oracle) takes one.
  let cards = [
    card("a", "1", "Reprint Old", 2, "2010-01-01", "same", attrs.Rare, "G"),
    card("b", "2", "Reprint New", 2, "2020-01-01", "same", attrs.Rare, "G"),
  ]
  let buckets = rule_cascade.project(owner_cascade(), cards)

  let color_binder = find_bucket(buckets, "binder G")
  assert color_binder.total_quantity == 1

  // Prefer the oldest printing: the claimed copy is set "a" (released earlier).
  let assert [assignment] = color_binder.cards
  assert card_key.set_code_string(assignment.card.key) == "a"

  // The other 3 copies fall through to bulk.
  let bulk = find_bucket(buckets, "Bulk")
  assert bulk.total_quantity == 3
}

// A card whose printing isn't in the catalog (no attributes) fails every
// attribute predicate and lands wholly in bulk.
pub fn catalog_unknown_card_falls_to_bulk_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "pxyz", collector_number: "1")
  let unknown =
    attrs.PlannedCard(
      key:,
      name: "Mystery Promo",
      quantity: 3,
      released_at: "",
      oracle_id: None,
      rarity: None,
      color_identity: None,
      card_type: None,
    )
  let buckets = rule_cascade.project(owner_cascade(), [unknown])
  assert list.length(buckets) == 1
  let bulk = find_bucket(buckets, "Bulk")
  assert bulk.total_quantity == 3
}

// Empty collection -> no buckets.
pub fn empty_collection_yields_no_buckets_test() {
  assert rule_cascade.project(owner_cascade(), []) == []
}

// Conservation still holds when quantities and rarities vary widely.
pub fn conservation_across_generated_cases_test() {
  let quantities = [1, 2, 3, 4, 7, 12]
  let cases =
    list.map(quantities, fn(q) {
      [
        card("grn", "1", "A", q, "2018-10-05", "o1", attrs.Rare, "R"),
        card("dom", "2", "B", q, "2018-04-27", "o2", attrs.Common, "W"),
        card("grn", "3", "C", q, "2018-10-05", "o1", attrs.Rare, "R"),
      ]
    })
  assert list.all(cases, conservation_holds)
}

// Duplicate printing keys in the input pool their quantities: nothing is
// overwritten on intake and the remainder drains into bulk exactly once.
pub fn duplicate_printing_keys_conserve_quantity_test() {
  let cards = [
    card("grn", "173", "Guildmage", 2, "2018-10-05", "o1", attrs.Rare, "R"),
    card("grn", "173", "Guildmage", 3, "2018-10-05", "o1", attrs.Rare, "R"),
  ]
  assert conservation_holds(cards)

  // 5 copies: 1 to the set binder, 1 to the color binder, 3 to bulk.
  let buckets = rule_cascade.project(owner_cascade(), cards)
  let bulk = find_bucket(buckets, "Bulk")
  assert bulk.total_quantity == 3
}

// No bucket ever carries a negative total.
pub fn no_negative_totals_test() {
  let cards = [
    card("grn", "173", "Guildmage", 4, "2018-10-05", "o1", attrs.Rare, "R"),
    card("m19", "5", "Common Card", 3, "2018-07-13", "o2", attrs.Common, "U"),
  ]
  let buckets = rule_cascade.project(owner_cascade(), cards)
  assert list.all(buckets, fn(b) { b.total_quantity >= 0 })
  assert list.all(buckets, fn(b) { list.all(b.cards, fn(a) { a.quantity > 0 }) })
}

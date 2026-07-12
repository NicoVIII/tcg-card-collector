import gleam/dict
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
import inventory_planning/domain/set_index.{SetMeta}
import inventory_planning/domain/sort_spec
import shared/domain/card_key

// A SetIndex of root sets (no parents) with the given release dates.
fn set_dates(entries: List(#(String, String))) -> set_index.SetIndex {
  entries
  |> list.map(fn(entry) {
    let #(code, date) = entry
    #(code, SetMeta(released_at: date, parent_set_code: None))
  })
  |> dict.from_list
}

// A SetIndex with explicit parent links: #(code, released_at, parent).
fn build_index(
  entries: List(#(String, String, option.Option(String))),
) -> set_index.SetIndex {
  entries
  |> list.map(fn(entry) {
    let #(code, date, parent) = entry
    #(code, SetMeta(released_at: date, parent_set_code: parent))
  })
  |> dict.from_list
}

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
  sorted_rule(id, position, selector, predicate_src, target_src, [])
}

fn sorted_rule(
  id: String,
  position: Int,
  selector: copy_selector.CopySelector,
  predicate_src: String,
  target_src: String,
  sort_keys: List(sort_spec.SortKey),
) -> CascadeRule {
  let assert Ok(predicate) = card_predicate.parse(predicate_src)
  CascadeRule(
    id:,
    position:,
    selector:,
    predicate:,
    target: location_target.parse(target_src),
    sort_keys:,
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
      sort_spec.ByColorIdentity,
      sort_spec.ByCardType,
      sort_spec.ByName,
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
  let buckets = rule_cascade.project(owner_cascade(), cards, dict.new())
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
  let buckets = rule_cascade.project(owner_cascade(), cards, dict.new())

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
    rule_cascade.project(owner_cascade(), cards, dict.new())
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
  let buckets = rule_cascade.project(owner_cascade(), cards, dict.new())

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
  let buckets = rule_cascade.project(owner_cascade(), [unknown], dict.new())
  assert list.length(buckets) == 1
  let bulk = find_bucket(buckets, "Bulk")
  assert bulk.total_quantity == 3
}

// Empty collection -> no buckets.
pub fn empty_collection_yields_no_buckets_test() {
  assert rule_cascade.project(owner_cascade(), [], dict.new()) == []
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
  let buckets = rule_cascade.project(owner_cascade(), cards, dict.new())
  let bulk = find_bucket(buckets, "Bulk")
  assert bulk.total_quantity == 3
}

// A single all-copies rule claiming every card into one fixed location, laid
// out by the rule's sort keys.
fn shelf_cascade(sort_keys: List(sort_spec.SortKey)) -> RuleCascade {
  RuleCascade(
    rules: [
      sorted_rule(
        "shelf",
        1,
        copy_selector.AllCopies,
        "rarity >= common",
        "Shelf",
        sort_keys,
      ),
    ],
    bulk: bulk_spec.BulkSpec("Bulk", []),
  )
}

// A rule laying its bucket out by name reorders cards away from the canonical
// (release-date) order they were claimed in.
pub fn rule_bucket_sorted_by_name_differs_from_canonical_test() {
  let cards = [
    card("aaa", "1", "Zebra", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("bbb", "2", "Apple", 1, "2001-01-01", "o2", attrs.Common, "R"),
  ]
  let shelf =
    find_bucket(
      rule_cascade.project(shelf_cascade([sort_spec.ByName]), cards, dict.new()),
      "Shelf",
    )
  assert list.map(shelf.cards, fn(a) { a.card.name }) == ["Apple", "Zebra"]
}

// Empty sort keys leave the canonical order (release date asc) untouched.
pub fn rule_bucket_empty_sort_keys_keep_canonical_order_test() {
  let cards = [
    card("aaa", "1", "Zebra", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("bbb", "2", "Apple", 1, "2001-01-01", "o2", attrs.Common, "R"),
  ]
  let shelf =
    find_bucket(
      rule_cascade.project(shelf_cascade([]), cards, dict.new()),
      "Shelf",
    )
  assert list.map(shelf.cards, fn(a) { a.card.name }) == ["Zebra", "Apple"]
}

// A template rule sorts each fanned-out bucket independently.
pub fn template_fan_out_buckets_sorted_independently_test() {
  let cascade =
    RuleCascade(
      rules: [
        sorted_rule(
          "binders",
          1,
          copy_selector.AllCopies,
          "rarity >= common",
          "Binder {color_identity}",
          [sort_spec.ByName],
        ),
      ],
      bulk: bulk_spec.BulkSpec("Bulk", []),
    )
  let cards = [
    card("aaa", "1", "Zebra", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("bbb", "2", "Apple", 1, "2001-01-01", "o2", attrs.Common, "R"),
    card("ccc", "3", "Yak", 1, "2000-01-01", "o3", attrs.Common, "G"),
    card("ddd", "4", "Bear", 1, "2001-01-01", "o4", attrs.Common, "G"),
  ]
  let buckets = rule_cascade.project(cascade, cards, dict.new())
  let red = find_bucket(buckets, "Binder R")
  let green = find_bucket(buckets, "Binder G")
  assert list.map(red.cards, fn(a) { a.card.name }) == ["Apple", "Zebra"]
  assert list.map(green.cards, fn(a) { a.card.name }) == ["Bear", "Yak"]
}

// --- Semantic fan-out ordering -------------------------------------------

fn set_binder_cascade() -> RuleCascade {
  RuleCascade(
    rules: [
      sorted_rule(
        "binders",
        1,
        copy_selector.AllCopies,
        "rarity >= common",
        "Binder {set_code}",
        [],
      ),
    ],
    bulk: bulk_spec.BulkSpec("Bulk", []),
  )
}

fn color_binder_cascade() -> RuleCascade {
  RuleCascade(
    rules: [
      sorted_rule(
        "binders",
        1,
        copy_selector.AllCopies,
        "rarity >= common",
        "Binder {color_identity}",
        [],
      ),
    ],
    bulk: bulk_spec.BulkSpec("Bulk", []),
  )
}

fn type_binder_cascade() -> RuleCascade {
  RuleCascade(
    rules: [
      sorted_rule(
        "binders",
        1,
        copy_selector.AllCopies,
        "rarity >= common",
        "Shelf {type}",
        [],
      ),
    ],
    bulk: bulk_spec.BulkSpec("Bulk", []),
  )
}

// {set_code} fan-out ordered by dict release date, not alphabetically.
// "zzz" (2000) precedes "aaa" (2010) by date even though "aaa" < "zzz" lexically.
pub fn set_fan_out_ordered_by_release_date_test() {
  let dates = set_dates([#("zzz", "2000-01-01"), #("aaa", "2010-01-01")])
  let cards = [
    card("zzz", "1", "Old Card", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("aaa", "2", "New Card", 1, "2010-01-01", "o2", attrs.Common, "R"),
  ]
  let buckets = rule_cascade.project(set_binder_cascade(), cards, dates)
  let names = list.map(buckets, fn(b) { b.location_name })
  assert names == ["Binder zzz", "Binder aaa"]
}

// When no dict entry exists, falls back to card's released_at.
pub fn set_fan_out_card_date_fallback_test() {
  let cards = [
    card("zzz", "1", "Old Card", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("aaa", "2", "New Card", 1, "2010-01-01", "o2", attrs.Common, "R"),
  ]
  // Empty dict → fallback to card.released_at (2000 < 2010 → zzz before aaa)
  let buckets = rule_cascade.project(set_binder_cascade(), cards, dict.new())
  let names = list.map(buckets, fn(b) { b.location_name })
  assert names == ["Binder zzz", "Binder aaa"]
}

// Dict takes priority over card.released_at when present and non-empty.
pub fn set_fan_out_dict_overrides_card_date_test() {
  // Card dates say zzz(2000) < aaa(2010), but dict reverses: zzz→2020, aaa→1990
  let dates = set_dates([#("zzz", "2020-01-01"), #("aaa", "1990-01-01")])
  let cards = [
    card("zzz", "1", "Old Card", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("aaa", "2", "New Card", 1, "2010-01-01", "o2", attrs.Common, "R"),
  ]
  let buckets = rule_cascade.project(set_binder_cascade(), cards, dates)
  let names = list.map(buckets, fn(b) { b.location_name })
  // aaa (1990) now precedes zzz (2020)
  assert names == ["Binder aaa", "Binder zzz"]
}

// The card-date fallback takes the minimum non-empty released_at among the
// bucket's cards — a date-less card (which is canonically first and would be
// the bucket witness) must not drag the bucket's date down to "unknown".
pub fn set_fan_out_fallback_skips_empty_card_dates_test() {
  let cards = [
    // "zzz" bucket: one date-less card + one dated 2015 → bucket date 2015
    card("zzz", "1", "Dateless", 1, "", "o1", attrs.Common, "R"),
    card("zzz", "2", "Dated Late", 1, "2015-01-01", "o2", attrs.Common, "R"),
    card("aaa", "3", "Dated Early", 1, "2010-01-01", "o3", attrs.Common, "R"),
  ]
  let buckets = rule_cascade.project(set_binder_cascade(), cards, dict.new())
  let names = list.map(buckets, fn(b) { b.location_name })
  // aaa (2010) before zzz (2015); witness-date semantics would put zzz ("")
  // first instead.
  assert names == ["Binder aaa", "Binder zzz"]
}

// Mixed sources compare against each other: one set's date from the dict, the
// other falling back to its card date.
pub fn set_fan_out_mixed_dict_and_fallback_test() {
  // "zzz" only in the dict (2005) — its card date is empty, so the dict is the
  // sole source; "aaa" absent from the dict → card date (2010).
  let dates = set_dates([#("zzz", "2005-01-01")])
  let cards = [
    card("zzz", "1", "Dict Card", 1, "", "o1", attrs.Common, "R"),
    card("aaa", "2", "Fallback Card", 1, "2010-01-01", "o2", attrs.Common, "R"),
  ]
  let buckets = rule_cascade.project(set_binder_cascade(), cards, dates)
  let names = list.map(buckets, fn(b) { b.location_name })
  assert names == ["Binder zzz", "Binder aaa"]
}

// Same date → alphabetical set_code tie-break.
pub fn set_fan_out_same_date_alphabetical_tiebreak_test() {
  let dates = set_dates([#("bbb", "2000-01-01"), #("aaa", "2000-01-01")])
  let cards = [
    card("bbb", "1", "B Card", 1, "2000-01-01", "o1", attrs.Common, "R"),
    card("aaa", "2", "A Card", 1, "2000-01-01", "o2", attrs.Common, "R"),
  ]
  let buckets = rule_cascade.project(set_binder_cascade(), cards, dates)
  let names = list.map(buckets, fn(b) { b.location_name })
  assert names == ["Binder aaa", "Binder bbb"]
}

// {color_identity} fan-out: WUBRG then multicolor then colorless.
// Colorless ("") would sort first alphabetically but last by WUBRG rank.
pub fn color_fan_out_wubrg_order_test() {
  let cards = [
    card("a", "1", "Card W", 1, "2000-01-01", "o1", attrs.Common, "W"),
    card("b", "2", "Card B", 1, "2000-01-01", "o2", attrs.Common, "B"),
    card("c", "3", "Card G", 1, "2000-01-01", "o3", attrs.Common, "G"),
    card("d", "4", "Card R", 1, "2000-01-01", "o4", attrs.Common, "R"),
    card("e", "5", "Card U", 1, "2000-01-01", "o5", attrs.Common, "U"),
    card("f", "6", "Colorless", 1, "2000-01-01", "o6", attrs.Common, ""),
  ]
  let buckets = rule_cascade.project(color_binder_cascade(), cards, dict.new())
  let names = list.map(buckets, fn(b) { b.location_name })
  // W < U < B < R < G (single colors); Colorless last.
  // Alphabetically "Binder Colorless" would sort before all (C < G, R, U, W, B)
  // which shows the WUBRG ordering differs from alphabetical.
  assert names
    == [
      "Binder W",
      "Binder U",
      "Binder B",
      "Binder R",
      "Binder G",
      "Binder Colorless",
    ]
}

// {type} fan-out: type rank order, not alphabetical.
// Land (rank 0) sorts before Artifact (rank 2), but alphabetically
// "artifact" < "land" — so rank ordering reverses the alphabetical default.
pub fn type_fan_out_rank_order_test() {
  let make_typed = fn(set_code, cn, card_type) {
    let assert Ok(key) =
      card_key.from_user_input(set_code:, collector_number: cn)
    attrs.PlannedCard(
      key:,
      name: set_code,
      quantity: 1,
      released_at: "2000-01-01",
      oracle_id: Some("o-" <> set_code),
      rarity: Some(attrs.Common),
      color_identity: None,
      card_type: Some(card_type),
    )
  }
  let land = make_typed("aaa", "1", attrs.Land)
  let artifact = make_typed("bbb", "2", attrs.Artifact)
  let buckets =
    rule_cascade.project(type_binder_cascade(), [land, artifact], dict.new())
  let names = list.map(buckets, fn(b) { b.location_name })
  // Rank: land (0) < artifact (2) → "Shelf land" first.
  // Alphabetical would give "Shelf artifact" first (a < l).
  assert names == ["Shelf land", "Shelf artifact"]
}

// No bucket ever carries a negative total.
pub fn no_negative_totals_test() {
  let cards = [
    card("grn", "173", "Guildmage", 4, "2018-10-05", "o1", attrs.Rare, "R"),
    card("m19", "5", "Common Card", 3, "2018-07-13", "o2", attrs.Common, "U"),
  ]
  let buckets = rule_cascade.project(owner_cascade(), cards, dict.new())
  assert list.all(buckets, fn(b) { b.total_quantity >= 0 })
  assert list.all(buckets, fn(b) { list.all(b.cards, fn(a) { a.quantity > 0 }) })
}

// --- Set-family fan-out ---------------------------------------------------

fn family_binder_cascade(sort_keys: List(sort_spec.SortKey)) -> RuleCascade {
  RuleCascade(
    rules: [
      sorted_rule(
        "binders",
        1,
        copy_selector.AllCopies,
        "rarity >= common",
        "Binder {set_family}",
        sort_keys,
      ),
    ],
    bulk: bulk_spec.BulkSpec("Bulk", []),
  )
}

// A parent set and its child (token) set collapse into one family bucket, named
// for the root, with the root card first and the child card after.
pub fn family_parent_and_child_merge_into_one_bucket_test() {
  let sets =
    build_index([
      #("grn", "2018-10-05", None),
      #("tgrn", "2018-10-05", Some("grn")),
    ])
  let cards = [
    card("grn", "173", "Guildmage", 1, "2018-10-05", "o1", attrs.Common, "R"),
    card("tgrn", "1", "Saproling", 1, "2018-10-05", "o2", attrs.Common, "G"),
  ]
  let buckets = rule_cascade.project(family_binder_cascade([]), cards, sets)
  assert list.length(buckets) == 1
  let bucket = find_bucket(buckets, "Binder grn")
  assert bucket.total_quantity == 2
  assert list.map(bucket.cards, fn(a) { card_key.set_code_string(a.card.key) })
    == ["grn", "tgrn"]
}

// Root-set cards stay first even when the rule's sort keys would interleave the
// child ahead of the root (root name sorts after the token name).
pub fn family_root_first_beats_sort_keys_test() {
  let sets =
    build_index([
      #("grn", "2018-10-05", None),
      #("tgrn", "2018-10-05", Some("grn")),
    ])
  let cards = [
    card("grn", "173", "Zzz Root", 1, "2018-10-05", "o1", attrs.Common, "R"),
    card("tgrn", "1", "Aaa Token", 1, "2018-10-05", "o2", attrs.Common, "G"),
  ]
  let buckets =
    rule_cascade.project(family_binder_cascade([sort_spec.ByName]), cards, sets)
  let bucket = find_bucket(buckets, "Binder grn")
  // Name sort alone would put "Aaa Token" first; family segregation keeps the
  // root ("Zzz Root") ahead.
  assert list.map(bucket.cards, fn(a) { a.card.name })
    == ["Zzz Root", "Aaa Token"]
}

// Two child sets within a family order by their own release date, then set code,
// after the root card.
pub fn family_children_order_by_date_then_code_test() {
  let sets =
    build_index([
      #("grn", "2018-10-05", None),
      #("pgrn", "2018-11-01", Some("grn")),
      #("tgrn", "2018-09-01", Some("grn")),
    ])
  let cards = [
    card("grn", "173", "Root", 1, "2018-10-05", "o0", attrs.Common, "R"),
    card("pgrn", "1", "Promo", 1, "2018-11-01", "o1", attrs.Common, "R"),
    card("tgrn", "1", "Token", 1, "2018-09-01", "o2", attrs.Common, "G"),
  ]
  let buckets = rule_cascade.project(family_binder_cascade([]), cards, sets)
  let bucket = find_bucket(buckets, "Binder grn")
  // Root first, then children oldest-first: tgrn (2018-09) before pgrn (2018-11).
  assert list.map(bucket.cards, fn(a) { card_key.set_code_string(a.card.key) })
    == ["grn", "tgrn", "pgrn"]
}

// Two family buckets cross-sort by their root's release date from the index —
// even when no root-set card is owned and the owned tokens' dates disagree.
pub fn family_buckets_cross_sort_by_root_date_test() {
  let sets =
    build_index([
      #("old", "2000-01-01", None),
      // Token dates deliberately reverse the root order, to prove the bucket
      // dates off the root via the index, not off the owned token cards.
      #("told", "2011-01-01", Some("old")),
      #("new", "2010-01-01", None),
      #("tnew", "2001-01-01", Some("new")),
    ])
  let cards = [
    card("tnew", "1", "New Token", 1, "2001-01-01", "o1", attrs.Common, "R"),
    card("told", "2", "Old Token", 1, "2011-01-01", "o2", attrs.Common, "R"),
  ]
  let buckets = rule_cascade.project(family_binder_cascade([]), cards, sets)
  let names = list.map(buckets, fn(b) { b.location_name })
  assert names == ["Binder old", "Binder new"]
}

// A set absent from the index is its own family, landing in its own bucket.
pub fn family_unknown_set_is_own_bucket_test() {
  let cards = [
    card("xyz", "1", "Mystery", 1, "2005-01-01", "o1", attrs.Common, "R"),
  ]
  let buckets =
    rule_cascade.project(family_binder_cascade([]), cards, dict.new())
  let bucket = find_bucket(buckets, "Binder xyz")
  assert bucket.total_quantity == 1
}

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/sort_section.{Section, SectionPart}
import inventory_planning/domain/sort_spec.{
  ByCardType, ByCollectorNumber, ByColorIdentity, ByManaValue, ByName,
}
import shared/domain/card_key
import shared/domain/finish
import shared/domain/language
import shared/domain/mana_value
import shared/domain/oracle_id
import shared/domain/rarity

fn base_card(collector_number: String, colors: String) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "set", collector_number:)
  let assert Ok(color_identity) = attrs.parse_color_identity(colors)
  let assert Ok(oracle) = oracle_id.new("o" <> collector_number)
  attrs.PlannedCard(
    key:,
    name: collector_number,
    quantity: 1,
    finish: finish.Nonfoil,
    language: language.En,
    released_at: None,
    oracle_id: Some(oracle),
    rarity: Some(rarity.Common),
    color_identity: Some(color_identity),
    card_type: Some(attrs.Creature),
    supertypes: Some([]),
    cmc: None,
    is_token: Some(False),
  )
}

fn cmc(value: Float) -> option.Option(mana_value.ManaValue) {
  let assert Ok(mv) = mana_value.from_float(value)
  Some(mv)
}

// A row of `copies` physical copies of a card, all sharing `colors` and
// `cmc_value` — one distinct printing per (collector_number, colors,
// cmc_value) combination the tests need, since a distinct printing is what a
// row represents.
fn row(
  collector_number: String,
  colors: String,
  cmc_value: Float,
  copies: Int,
) -> #(PlannedCard, Int) {
  #(
    attrs.PlannedCard(
      ..base_card(collector_number, colors),
      cmc: cmc(cmc_value),
    ),
    copies,
  )
}

fn card_type_row(
  collector_number: String,
  colors: String,
  card_type: attrs.CardType,
  copies: Int,
) -> #(PlannedCard, Int) {
  #(
    attrs.PlannedCard(
      ..base_card(collector_number, colors),
      card_type: Some(card_type),
    ),
    copies,
  )
}

fn card_type_cmc_row(
  collector_number: String,
  colors: String,
  card_type: attrs.CardType,
  cmc_value: Float,
  copies: Int,
) -> #(PlannedCard, Int) {
  #(
    attrs.PlannedCard(
      ..base_card(collector_number, colors),
      card_type: Some(card_type),
      cmc: cmc(cmc_value),
    ),
    copies,
  )
}

pub fn no_keys_yields_one_undivided_section_test() {
  let rows = [row("1", "W", 1.0, 20)]
  assert sort_section.sections([], rows) == [Section([], 20)]
}

pub fn no_rows_yields_no_sections_test() {
  assert sort_section.sections([ByColorIdentity], []) == []
}

// A location too small to clear the threshold on this key at all still
// gets one section covering everything — nothing to divide, so no header.
pub fn below_threshold_yields_one_undivided_section_test() {
  let rows = [row("1", "W", 1.0, 5), row("2", "U", 1.0, 5)]
  assert sort_section.sections([ByColorIdentity], rows) == [Section([], 10)]
}

// Two colors each clearing the threshold on their own become two sections,
// each a single value (first == last), covering every row.
pub fn two_categories_above_threshold_yield_two_sections_test() {
  let rows = [row("1", "U", 1.0, 20), row("2", "R", 1.0, 20)]
  let sections = sort_section.sections([ByColorIdentity], rows)
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByColorIdentity, "U", "U")],
      [SectionPart(ByColorIdentity, "R", "R")],
    ]
  assert list.map(sections, fn(s) { s.card_count }) == [20, 20]
  assert list.fold(sections, 0, fn(sum, s) { sum + s.card_count })
    == list.fold(rows, 0, fn(sum, r) { sum + r.1 })
}

// Sparse categories merge into a range wide enough to clear the threshold —
// cmc 1/2/3 (6 copies each) merge into one "1-3" section, cmc 4/5/6 into a
// second "4-6" section.
pub fn sparse_categories_merge_into_ranges_test() {
  let rows = [
    row("1", "R", 1.0, 6),
    row("2", "R", 2.0, 6),
    row("3", "R", 3.0, 6),
    row("4", "R", 4.0, 6),
    row("5", "R", 5.0, 6),
    row("6", "R", 6.0, 6),
  ]
  let sections = sort_section.sections([ByManaValue], rows)
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByManaValue, "1", "3")],
      [SectionPart(ByManaValue, "4", "6")],
    ]
  assert list.map(sections, fn(s) { s.card_count }) == [18, 18]
}

// name groups by first letter the same way, merging sparse letters into an
// "A-C"/"D-F"-style ranges — needs two threshold's worth of copies (36) so
// the merge actually has to divide the list rather than fold it all into one
// covering range (which would drop the key instead, see the test below).
pub fn sparse_name_categories_merge_by_first_letter_test() {
  let names = [
    "Ambush Viper",
    "Brainstorm",
    "Counterspell",
    "Doom Blade",
    "Electrolyze",
    "Fireball",
  ]
  let rows =
    list.index_map(names, fn(name, i) {
      #(attrs.PlannedCard(..base_card(int.to_string(i), "R"), name:), 6)
    })
  let sections = sort_section.sections([ByName], rows)
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByName, "A", "C")],
      [SectionPart(ByName, "D", "F")],
    ]
  assert list.map(sections, fn(s) { s.card_count }) == [18, 18]
}

// A merged (nested) key that never individually clears the threshold, but
// whose parent range does, contributes no part of its own — the label
// stops at the outer key rather than showing a range so wide it's useless.
// Both colors (W, U) clear the threshold alone, so both survive as their own
// section. Within W's 20 copies, type splits into two runs of 10 that only
// clear the threshold by merging together into one covering range, so type
// is dropped from W's label; within U's 40 copies, type splits into two
// runs of 20 that each clear the threshold alone, so U keeps a type part —
// a key's fate is decided per section, from that section's own rows, never
// conflated with a sibling section's.
pub fn sparse_inner_key_drops_out_of_label_test() {
  let rows = [
    card_type_row("1", "W", attrs.Creature, 10),
    card_type_row("2", "W", attrs.Artifact, 10),
    card_type_row("3", "U", attrs.Land, 20),
    card_type_row("4", "U", attrs.Enchantment, 20),
  ]
  let sections = sort_section.sections([ByColorIdentity, ByCardType], rows)
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByColorIdentity, "W", "W")],
      [
        SectionPart(ByColorIdentity, "U", "U"),
        SectionPart(ByCardType, "land", "land"),
      ],
      [
        SectionPart(ByColorIdentity, "U", "U"),
        SectionPart(ByCardType, "enchantment", "enchantment"),
      ],
    ]
  assert list.map(sections, fn(s) { s.card_count }) == [20, 20, 20]
}

// Regression: a merged (first != last) outer range must not recurse into
// the next key, while a single-value range still does. Rows are sorted by
// the full key tuple, so cmc is only monotonic *within* one color — across
// the merged W-U range, U's cmc (1) is lower than W's (3), so recursing
// anyway (the original design) built `SectionPart(ByManaValue, "3", "1")`:
// a range that reads backwards, because "last" picked up whichever color's
// run the merge happened to close on, not the true maximum. B never needed
// merging with a neighbour, so its own cmc split stays sound and shows up.
pub fn merged_outer_range_stops_recursion_into_next_key_test() {
  let rows = [
    row("1", "W", 3.0, 10),
    row("2", "U", 1.0, 10),
    row("3", "B", 1.0, 18),
    row("4", "B", 2.0, 18),
  ]
  let sections = sort_section.sections([ByColorIdentity, ByManaValue], rows)
  assert sections
    == [
      Section([SectionPart(ByColorIdentity, "W", "U")], 20),
      Section(
        [
          SectionPart(ByColorIdentity, "B", "B"),
          SectionPart(ByManaValue, "1", "1"),
        ],
        18,
      ),
      Section(
        [
          SectionPart(ByColorIdentity, "B", "B"),
          SectionPart(ByManaValue, "2", "2"),
        ],
        18,
      ),
    ]
}

// The same hazard one level deeper, and from the *other* unsafe path: a key
// whose values are heterogeneous but never clear the threshold even all
// merged together (`split_by_key`'s `[_only_range]` case, distinct from
// `section_for_range`'s "this range merged several values" case above). Type
// is homogeneous ("creature" throughout) so it adds no label and safely
// hands cmc the same rows; cmc then merges its two sparse values into one
// blob — genuinely heterogeneous, so recursing into name would restart once
// per cmc value (cmc 1's names, then cmc 2's names again from the top) and
// could build a backwards range — the exact shape that surfaced against real
// data (#138's QA pass): `type:creature-creature | name:T-R` on a real
// "Bulk RG" bucket, with cmc having silently dropped out in between. The fix
// stops at cmc, unlabeled, rather than let name read the restarted sequence.
pub fn heterogeneous_unmergeable_key_stops_recursion_into_next_key_test() {
  let #(card_1, copies_1) = row("1", "R", 1.0, 5)
  let #(card_2, copies_2) = row("2", "R", 2.0, 5)
  let rows = [
    #(attrs.PlannedCard(..card_1, name: "Zebra"), copies_1),
    #(attrs.PlannedCard(..card_2, name: "Apple"), copies_2),
  ]
  let sections = sort_section.sections([ByCardType, ByManaValue, ByName], rows)
  assert sections == [Section([], 10)]
}

// collector_number yields no category (sort_spec.category returns None):
// the label stops there, even with further keys behind it in the DSL.
pub fn collector_number_stops_the_label_test() {
  let rows = [row("1", "U", 1.0, 20), row("2", "R", 2.0, 20)]
  let sections =
    sort_section.sections(
      [ByColorIdentity, ByCollectorNumber, ByManaValue],
      rows,
    )
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByColorIdentity, "U", "U")],
      [SectionPart(ByColorIdentity, "R", "R")],
    ]
}

// #144 regression: a run that clears the threshold alone (creature, 40) must
// never be merged away by a tiny neighbour (land, 4) — land stays its own
// undersized section, and creature keeps recursing into cmc, unlike before
// the fix where land's 4 copies would have dragged creature into one
// "land-creature" range that could no longer subdivide.
pub fn self_sufficient_run_next_to_tiny_run_still_subdivides_test() {
  let rows = [
    card_type_cmc_row("1", "W", attrs.Land, 0.0, 4),
    card_type_cmc_row("2", "W", attrs.Creature, 1.0, 20),
    card_type_cmc_row("3", "W", attrs.Creature, 2.0, 20),
  ]
  let sections = sort_section.sections([ByCardType, ByManaValue], rows)
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByCardType, "land", "land")],
      [
        SectionPart(ByCardType, "creature", "creature"),
        SectionPart(ByManaValue, "1", "1"),
      ],
      [
        SectionPart(ByCardType, "creature", "creature"),
        SectionPart(ByManaValue, "2", "2"),
      ],
    ]
  assert list.map(sections, fn(s) { s.card_count }) == [4, 20, 20]
}

// Three undersized runs (6 each) next to each other merge into one 18-copy
// range, same as before the fix. A self-sufficient run (20) right after them
// is never pulled into that merge. A trailing undersized run (5) with no
// undersized neighbour left to join stands alone, below the floor — the
// relaxation #144 accepts.
pub fn consecutive_undersized_runs_merge_with_each_other_only_test() {
  let rows = [
    row("1", "R", 1.0, 6),
    row("2", "R", 2.0, 6),
    row("3", "R", 3.0, 6),
    row("4", "R", 4.0, 20),
    row("5", "R", 5.0, 5),
  ]
  let sections = sort_section.sections([ByManaValue], rows)
  assert list.map(sections, fn(s) { s.parts })
    == [
      [SectionPart(ByManaValue, "1", "3")],
      [SectionPart(ByManaValue, "4", "4")],
      [SectionPart(ByManaValue, "5", "5")],
    ]
  assert list.map(sections, fn(s) { s.card_count }) == [18, 20, 5]
}

// An undersized trailing run (5) with an undersized group right before it
// that already cleared the floor (10+10=20) joins that group rather than
// standing alone — settles #144's open question by reusing the existing
// join-the-prior-range behaviour for the whole undersized stretch, not just
// a single trailing run. A self-sufficient run (20) after the stretch keeps
// this from collapsing into the single-blob "no label" case, so the merged
// "1-3" range's label is actually visible.
pub fn undersized_tail_joins_its_undersized_stretch_test() {
  let rows = [
    row("1", "R", 1.0, 10),
    row("2", "R", 2.0, 10),
    row("3", "R", 3.0, 5),
    row("4", "R", 4.0, 20),
  ]
  let sections = sort_section.sections([ByManaValue], rows)
  assert sections
    == [
      Section([SectionPart(ByManaValue, "1", "3")], 25),
      Section([SectionPart(ByManaValue, "4", "4")], 20),
    ]
}

// Every section's card_count sums to the input's total copies, regardless
// of how many keys or how they merge.
pub fn card_counts_always_sum_to_input_test() {
  let rows = [
    row("1", "W", 1.0, 4),
    row("2", "U", 2.0, 7),
    row("3", "B", 2.0, 3),
    row("4", "R", 3.0, 9),
  ]
  let total = list.fold(rows, 0, fn(sum, r) { sum + r.1 })
  let sections = sort_section.sections([ByColorIdentity, ByManaValue], rows)
  assert list.fold(sections, 0, fn(sum, s) { sum + s.card_count }) == total
}

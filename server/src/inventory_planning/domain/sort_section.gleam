import gleam/list
import gleam/option.{None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard}
import inventory_planning/domain/sort_spec.{type SortKey}

// A physical section of a location's card list, one or more sort-key
// categories wide (#138): the label a user finds on the divider before
// hunting for the exact neighbour-anchored slot. `first == last` in a part
// means every card in the section shares that one category value; a
// differing pair means the part is a merged range ("CMC 1-3", "A-E").
pub type SectionPart {
  SectionPart(key: SortKey, first: String, last: String)
}

// A contiguous run of a location's sorted cards. `parts` is empty when the
// location has no sort keys, or when every key's categories collapsed into
// one range (nothing to divide) — the caller shows no header for it.
pub type Section {
  Section(parts: List(SectionPart), card_count: Int)
}

// Two 9-pocket binder pages: coarse enough to be worth a physical divider,
// fine enough to still narrow a search within a large bulk box.
const min_section_copies = 18

// Partitions `rows` (cards already sorted by `keys`, each paired with its
// physical copy count) into contiguous sections covering every row exactly
// once — `sum(card_count) == length(rows)` always holds. Keys are applied
// outermost-first, and a key never contributes a part unless it distinguishes
// at least two ranges' worth of the location — but *whether recursing into
// the next key is still sound* is a separate question from whether this key
// showed a label, because rows are sorted by the full key tuple: a nested
// key is only monotonic *within one value* of the key above it. Once that
// key's rows hold more than one value, going deeper risks a nested key's own
// category restarting once per value it passed through (e.g. `type` covering
// both "artifact" and "enchantment" rows means `cmc` counts up once inside
// artifact, then again inside enchantment) — a first–last range built from
// that non-monotonic sequence would read backwards or repeat. So three cases,
// by how many distinct values `key` actually holds in `rows`:
// - Exactly one value throughout: no label, but every remaining key stays as
//   monotonic as it already was — safe to recurse on the same `rows`.
// - More than one value, and every one of them is too small to clear
//   `min_section_copies` even all merged together: no label is possible, and
//   the rows are genuinely heterogeneous in `key` — recursing further is
//   exactly the unsafe case above, so this key is the last one tried; the
//   section stops here, unlabeled.
// - Two or more ranges: each becomes its own part. A range that's a single,
//   unmerged value keeps recursing (still homogeneous for what's left); a
//   range that merged several values together keeps its own part but, same
//   as above, stops there. A value that clears the threshold alone is never
//   merged into a neighbour (#144) — an undersized value with no undersized
//   neighbour to join instead stands as its own part below the floor.
// A key that yields no category at all (sort_spec.category returns `None`)
// stops the recursion outright too, per that function's doc.
pub fn sections(
  keys: List(SortKey),
  rows: List(#(PlannedCard, Int)),
) -> List(Section) {
  split(keys, rows)
}

fn split(
  keys: List(SortKey),
  rows: List(#(PlannedCard, Int)),
) -> List(Section) {
  case keys, rows {
    _, [] -> []
    [], _ -> [Section([], copies_of(rows))]
    [key, ..rest], [#(witness, _), ..] ->
      case sort_spec.category(key, witness) {
        None -> [Section([], copies_of(rows))]
        Some(_) -> split_by_key(key, rest, rows)
      }
  }
}

fn split_by_key(
  key: SortKey,
  rest: List(SortKey),
  rows: List(#(PlannedCard, Int)),
) -> List(Section) {
  case runs(key, rows) {
    // Exactly one value throughout `rows`: nothing to divide on, and every
    // remaining key is exactly as monotonic as it already was.
    [_only_run] -> split(rest, rows)
    many_runs ->
      case merge_runs(many_runs) {
        // More than one value, but none of them (even merged with a
        // neighbour) clears the threshold: no label is possible, and unlike
        // the single-value case above, `rows` is genuinely heterogeneous in
        // `key` — recursing further is the unsafe case this function's doc
        // describes, so this is where the section stops.
        [_only_range] -> [Section([], copies_of(rows))]
        ranges ->
          list.flat_map(ranges, fn(range) {
            section_for_range(key, rest, range)
          })
      }
  }
}

fn section_for_range(
  key: SortKey,
  rest: List(SortKey),
  range: Range,
) -> List(Section) {
  let Range(first, last, range_rows) = range
  let part = SectionPart(key, first, last)
  case first == last {
    // A single, unmerged category: still homogeneous for every remaining
    // key, so recursing into the next one stays sound.
    True ->
      split(rest, range_rows)
      |> list.map(fn(section) {
        Section([part, ..section.parts], section.card_count)
      })
    // A merged range: see `sections`'s doc for why recursion stops here.
    False -> [Section([part], copies_of(range_rows))]
  }
}

fn copies_of(rows: List(#(PlannedCard, Int))) -> Int {
  list.fold(rows, 0, fn(sum, row) { sum + row.1 })
}

// One category value's contiguous run of rows, in original sort order.
type Run {
  Run(value: String, rows: List(#(PlannedCard, Int)))
}

// A merged range: one or more adjacent runs. `first`/`last` are the first
// and last run's values — equal when the range is exactly one run (nothing
// was merged). A range born from a run that cleared `min_section_copies` on
// its own is always a single run; a range born from merging undersized runs
// may still fall short of the floor at the edges (see `merge_runs`).
type Range {
  Range(first: String, last: String, rows: List(#(PlannedCard, Int)))
}

// Groups consecutive rows sharing the same category under `key` into runs,
// preserving sort order. Rows are pre-sorted by this key, so equal values are
// always adjacent — this never merges two separate occurrences of a value.
fn runs(key: SortKey, rows: List(#(PlannedCard, Int))) -> List(Run) {
  list.fold(rows, [], fn(acc, row) {
    let #(card, _) = row
    let value = sort_spec.category(key, card) |> option.unwrap("")
    case acc {
      [Run(current_value, current_rows), ..prior] if current_value == value -> [
        Run(current_value, list.append(current_rows, [row])),
        ..prior
      ]
      _ -> [Run(value, [row]), ..acc]
    }
  })
  |> list.reverse
}

fn clears_floor(run: Run) -> Bool {
  copies_of(run.rows) >= min_section_copies
}

// A run that clears `min_section_copies` on its own is never merged with a
// neighbour — merging it into a range would block *its own* subdivision by
// the next key (#144: a 4-copy `land` run swallowing a 975-copy `creature`
// run left `creature` unable to subdivide by `cmc`). So runs are first
// chunked into alternating stretches of "clears the floor" and "doesn't";
// a self-sufficient stretch yields one single-value range per run (still
// eligible to recurse), and only a stretch of consecutive undersized runs
// goes through the greedy merge below — merging with a self-sufficient
// neighbour is never on the table. An undersized stretch that never reaches
// the floor, even all merged together, stands as its own range below the
// floor: this deliberately relaxes "every labelled range clears the floor"
// at the edges, in exchange for never blocking a large neighbour's
// subdivision.
fn merge_runs(runs: List(Run)) -> List(Range) {
  runs
  |> list.chunk(clears_floor)
  |> list.flat_map(merge_stretch)
}

fn merge_stretch(stretch: List(Run)) -> List(Range) {
  case stretch {
    [first, ..] ->
      case clears_floor(first) {
        True ->
          list.map(stretch, fn(run) { Range(run.value, run.value, run.rows) })
        False -> merge_undersized(stretch)
      }
    [] -> []
  }
}

// Greedily merges adjacent (all-undersized) runs left to right until each
// merged range holds at least `min_section_copies` copies. A final run too
// small to clear the threshold on its own joins the range before it — or
// stands alone if it's the only range in the stretch.
fn merge_undersized(runs: List(Run)) -> List(Range) {
  let #(done_rev, open) =
    list.fold(runs, #([], None), fn(state, run) {
      let #(done_rev, open) = state
      let merged = case open {
        None -> Range(run.value, run.value, run.rows)
        Some(Range(first, _last, acc_rows)) ->
          Range(first, run.value, list.append(acc_rows, run.rows))
      }
      case copies_of(merged.rows) >= min_section_copies {
        True -> #([merged, ..done_rev], None)
        False -> #(done_rev, Some(merged))
      }
    })

  case open {
    None -> list.reverse(done_rev)
    Some(range) -> list.reverse(join_trailing(done_rev, range))
  }
}

// Folds an undersized trailing range into the range before it, or keeps it
// standing alone when it's the only range there is.
fn join_trailing(done_rev: List(Range), trailing: Range) -> List(Range) {
  case done_rev {
    [] -> [trailing]
    [Range(first, _last, prior_rows), ..rest] -> [
      Range(first, trailing.last, list.append(prior_rows, trailing.rows)),
      ..rest
    ]
  }
}

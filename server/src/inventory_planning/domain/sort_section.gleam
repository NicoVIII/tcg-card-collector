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
// outermost-first: a key's equal-category runs are merged into ranges of at
// least `min_section_copies` copies, then each range recurses on the
// remaining keys. A key whose merge collapses to a single range over its
// whole input contributes no part — it didn't distinguish anything worth a
// divider — and a key that yields no category (sort_spec.category returns
// `None`) stops the recursion outright, per that function's doc.
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
  case merge_runs(runs(key, rows)) {
    // Merging never distinguished more than one range: this key adds nothing
    // to the label, so it's skipped rather than emitting an empty part.
    [_single] -> split(rest, rows)
    ranges ->
      list.flat_map(ranges, fn(range) {
        let Range(first, last, range_rows) = range
        let part = SectionPart(key, first, last)
        split(rest, range_rows)
        |> list.map(fn(section) {
          Section([part, ..section.parts], section.card_count)
        })
      })
  }
}

fn copies_of(rows: List(#(PlannedCard, Int))) -> Int {
  list.fold(rows, 0, fn(sum, row) { sum + row.1 })
}

// One category value's contiguous run of rows, in original sort order.
type Run {
  Run(value: String, rows: List(#(PlannedCard, Int)))
}

// A merged range: one or more adjacent runs wide enough together to clear
// `min_section_copies`. `first`/`last` are the first and last run's values —
// equal when the range is exactly one run (nothing was merged).
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

// Greedily merges adjacent runs left to right until each merged range holds
// at least `min_section_copies` copies. A final run too small to clear the
// threshold on its own joins the range before it — the section-size promise
// holds even for a tail that never reaches it alone; a `rows` short enough
// overall to never clear the threshold yields the single range covering
// everything.
fn merge_runs(runs: List(Run)) -> List(Range) {
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

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import shared/domain/copy_key.{type CopyKey}

/// A ledger row about to be pruned: the key, the location losing copies, and
/// how many — not the row's remaining quantity, matching the DAO decrement
/// contract's "amount to subtract" shape.
pub type PlacedRow {
  PlacedRow(key: CopyKey, location: String, quantity: Int)
}

/// For any key whose placed total exceeds its owned quantity (0 when the key
/// is absent from `owned` — fully removed), prunes that key's locations in
/// alphabetical order until the excess is absorbed. A plain quantity change
/// carries no location to blame for the phantom copies, so this tie-break is
/// arbitrary but deterministic — ADR 0011. Keys already within bounds never
/// appear in the result.
pub fn excess_to_prune(
  owned: Dict(CopyKey, Int),
  placed: List(PlacedRow),
) -> List(PlacedRow) {
  placed
  |> group_by_key
  |> dict.to_list
  |> list.flat_map(fn(pair) {
    let #(key, rows) = pair
    let owned_quantity = dict.get(owned, key) |> option_unwrap(0)
    let total_placed = list.fold(rows, 0, fn(sum, row) { sum + row.quantity })
    let excess = total_placed - owned_quantity

    case excess > 0 {
      True -> prune(sort_by_location(rows), excess)
      False -> []
    }
  })
}

fn option_unwrap(result: Result(a, b), default: a) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> default
  }
}

fn group_by_key(rows: List(PlacedRow)) -> Dict(CopyKey, List(PlacedRow)) {
  list.fold(rows, dict.new(), fn(acc, row) {
    dict.upsert(acc, row.key, fn(existing) {
      case existing {
        Some(rows) -> [row, ..rows]
        None -> [row]
      }
    })
  })
}

fn sort_by_location(rows: List(PlacedRow)) -> List(PlacedRow) {
  list.sort(rows, fn(a, b) { string.compare(a.location, b.location) })
}

// Walks locations in order, taking as much as needed from each until the
// excess is absorbed, returning only the amount pruned from each row.
fn prune(rows: List(PlacedRow), excess: Int) -> List(PlacedRow) {
  case rows, excess {
    _, 0 -> []
    [], _ -> []
    [row, ..rest], remaining -> {
      let taken = int.min(row.quantity, remaining)
      [PlacedRow(..row, quantity: taken), ..prune(rest, remaining - taken)]
    }
  }
}

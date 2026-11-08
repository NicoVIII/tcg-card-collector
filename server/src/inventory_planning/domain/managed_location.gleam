import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/order.{type Order}
import gleam/result
import gleam/string
import shared/domain/copy_key.{type CopyKey}

/// What a managed location is (ADR 0022). Only decks so far; a second kind
/// (a trade box, a display case) shares everything below.
pub type ManagedLocationKind {
  Deck
}

pub fn kind_from_string(raw: String) -> Result(ManagedLocationKind, Nil) {
  case raw {
    "deck" -> Ok(Deck)
    _ -> Error(Nil)
  }
}

// An irrefutable let while Deck is the only kind; a second kind makes this a
// compile error, which is the point.
pub fn kind_to_string(kind: ManagedLocationKind) -> String {
  let Deck = kind
  "deck"
}

/// A named location whose contents are an explicit membership list rather
/// than a rule predicate (#122). Membership is intent: it says what the
/// location should hold, whether or not the collection owns that many right
/// now — the gap is a derived shortfall, never pruned from here.
pub type ManagedLocation {
  ManagedLocation(
    id: String,
    name: String,
    kind: ManagedLocationKind,
    members: Dict(CopyKey, Int),
  )
}

/// A trimmed, non-empty name. Uniqueness is `name_taken`'s job, since it
/// needs the other locations.
pub fn parse_name(raw: String) -> Result(String, Nil) {
  let name = string.trim(raw)
  use <- bool.guard(name == "", Error(Nil))
  Ok(name)
}

/// Whether another managed location (any but `except_id`) already uses
/// `name`. Names are unique among managed locations only — a deck may share
/// its name with a rule target, since they live in different LocationRef
/// namespaces.
pub fn name_taken(
  locations: List(ManagedLocation),
  name: String,
  except_id except_id: String,
) -> Bool {
  list.any(locations, fn(location) {
    location.id != except_id && location.name == name
  })
}

pub fn find(
  locations: List(ManagedLocation),
  id: String,
) -> Result(ManagedLocation, Nil) {
  list.find(locations, fn(location) { location.id == id })
}

fn compare_keys(a: CopyKey, b: CopyKey) -> Order {
  string.compare(copy_key.set_code_string(a), copy_key.set_code_string(b))
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.collector_number_string(a),
      copy_key.collector_number_string(b),
    )
  })
  |> order.lazy_break_tie(fn() {
    string.compare(copy_key.finish_string(a), copy_key.finish_string(b))
  })
  |> order.lazy_break_tie(fn() {
    string.compare(copy_key.language_string(a), copy_key.language_string(b))
  })
}

/// A requested change to one kind of copy's membership: always a positive
/// quantity; whether it's added or removed is the command's business.
pub type MemberDelta {
  MemberDelta(key: CopyKey, quantity: Int)
}

/// Parses one requested change from user input: a canonicalizable CopyKey
/// and a positive quantity.
pub fn delta_from_input(
  set_code set_code: String,
  collector_number collector_number: String,
  finish finish: String,
  language language: String,
  quantity quantity: Int,
) -> Result(MemberDelta, Nil) {
  use key <- result.try(
    copy_key.from_user_input(set_code:, collector_number:, finish:, language:)
    |> result.replace_error(Nil),
  )
  use <- bool.guard(quantity < 1, Error(Nil))
  Ok(MemberDelta(key:, quantity:))
}

/// Sums deltas sharing a key, so a check sees each key's whole request at
/// once rather than letting two half-requests each pass on their own.
pub fn merge_deltas(deltas: List(MemberDelta)) -> List(MemberDelta) {
  deltas
  |> list.fold(dict.new(), fn(acc, delta) {
    dict.upsert(acc, delta.key, fn(existing) {
      option.unwrap(existing, 0) + delta.quantity
    })
  })
  |> dict.to_list
  |> list.map(fn(pair) { MemberDelta(key: pair.0, quantity: pair.1) })
  |> list.sort(fn(a, b) { compare_keys(a.key, b.key) })
}

/// How many copies of each key all managed locations claim together.
pub fn claimed_totals(locations: List(ManagedLocation)) -> Dict(CopyKey, Int) {
  list.fold(locations, dict.new(), fn(acc, location) {
    dict.fold(location.members, acc, fn(acc, key, quantity) {
      dict.upsert(acc, key, fn(existing) {
        option.unwrap(existing, 0) + quantity
      })
    })
  })
}

/// An addition asked for more copies of a key than are free: owned, minus
/// what managed locations already claim (0 when they claim more than is
/// owned — a shortfall can't free anything up).
pub type Overclaim {
  Overclaim(key: CopyKey, requested: Int, available: Int)
}

/// Rejects the first delta whose key hasn't enough free copies; `claimed`
/// is `claimed_totals` across every managed location, the target included.
pub fn check_addition(
  deltas: List(MemberDelta),
  owned owned: Dict(CopyKey, Int),
  claimed claimed: Dict(CopyKey, Int),
) -> Result(Nil, Overclaim) {
  list.try_each(deltas, fn(delta) {
    let free = int.max(0, lookup(owned, delta.key) - lookup(claimed, delta.key))
    case delta.quantity > free {
      True ->
        Error(Overclaim(
          key: delta.key,
          requested: delta.quantity,
          available: free,
        ))
      False -> Ok(Nil)
    }
  })
}

/// A removal asked for more copies than the location holds.
pub type Underheld {
  Underheld(key: CopyKey, requested: Int, held: Int)
}

pub fn check_removal(
  location: ManagedLocation,
  deltas: List(MemberDelta),
) -> Result(Nil, Underheld) {
  list.try_each(deltas, fn(delta) {
    let held = lookup(location.members, delta.key)
    case delta.quantity > held {
      True -> Error(Underheld(key: delta.key, requested: delta.quantity, held:))
      False -> Ok(Nil)
    }
  })
}

/// The order managed locations take from a scarce pool in (ADR 0022): by
/// name, then id for determinism. Arbitrary, but a shortfall is always
/// visible, so the user can see which one came up short.
pub fn compare_precedence(a: ManagedLocation, b: ManagedLocation) -> Order {
  string.compare(a.name, b.name)
  |> order.lazy_break_tie(fn() { string.compare(a.id, b.id) })
}

/// `(key, quantity)` pairs in a stable key order — a Dict's own order is
/// unspecified, and the wire and the shortfall list must not reshuffle.
pub fn sorted_by_key(pairs: List(#(CopyKey, Int))) -> List(#(CopyKey, Int)) {
  list.sort(pairs, fn(a, b) { compare_keys(a.0, b.0) })
}

fn lookup(quantities: Dict(CopyKey, Int), key: CopyKey) -> Int {
  dict.get(quantities, key) |> result.unwrap(0)
}

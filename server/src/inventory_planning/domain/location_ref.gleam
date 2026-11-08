import gleam/bool
import gleam/order.{type Order}
import gleam/string

/// Where a copy sits, in one of two namespaces (#122): a cascade location
/// (a rule target or the bulk remainder) by its rendered name — ADR 0014's
/// text — or a managed location by its id. Two namespaces so a deck and a
/// binder can share a display name without their ledger rows merging, and so
/// renaming a managed location never touches the ledger.
///
/// The variants hold plain strings because the projection must be able to
/// name every location it renders, even one whose rule target renders empty;
/// `new` is the validating parse for anything arriving from outside.
pub type LocationRef {
  Cascade(name: String)
  Managed(id: String)
}

/// Parses the `(kind, key)` pair the wire and the database carry — `kind` is
/// "cascade" or "managed", `key` the name or id. The key is trimmed first, so
/// a whitespace-only one is as invalid as an empty one.
pub fn new(kind kind: String, key key: String) -> Result(LocationRef, Nil) {
  let key = string.trim(key)
  use <- bool.guard(key == "", Error(Nil))
  case kind {
    "cascade" -> Ok(Cascade(key))
    "managed" -> Ok(Managed(key))
    _ -> Error(Nil)
  }
}

pub fn kind_string(ref: LocationRef) -> String {
  case ref {
    Cascade(_) -> "cascade"
    Managed(_) -> "managed"
  }
}

pub fn key_string(ref: LocationRef) -> String {
  case ref {
    Cascade(name) -> name
    Managed(id) -> id
  }
}

/// Kind first, then key — a total order for deterministic tie-breaks, not a
/// physical or display order.
pub fn compare(a: LocationRef, b: LocationRef) -> Order {
  string.compare(kind_string(a), kind_string(b))
  |> order.lazy_break_tie(fn() { string.compare(key_string(a), key_string(b)) })
}

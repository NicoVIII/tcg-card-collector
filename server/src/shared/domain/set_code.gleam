import gleam/bool
import gleam/order.{type Order}
import gleam/string

// A set's canonical identifier ("m11", "grn"): trimmed, lowercase, non-empty.
pub opaque type SetCode {
  SetCode(value: String)
}

pub type SetCodeError {
  Empty
  NotCanonical
}

/// Strict constructor — accepts only already-canonical input (trimmed,
/// lowercase). Use from_user_input when the value comes from human-supplied
/// text.
pub fn new(raw: String) -> Result(SetCode, SetCodeError) {
  use <- bool.guard(raw == "", Error(Empty))
  use <- bool.guard(raw != canonicalize(raw), Error(NotCanonical))
  Ok(SetCode(raw))
}

/// Lenient constructor for user-supplied text: trims and lowercases.
pub fn from_user_input(raw: String) -> Result(SetCode, SetCodeError) {
  new(canonicalize(raw))
}

fn canonicalize(raw: String) -> String {
  raw |> string.trim |> string.lowercase
}

pub fn to_string(code: SetCode) -> String {
  code.value
}

pub fn compare(left: SetCode, right: SetCode) -> Order {
  string.compare(left.value, right.value)
}

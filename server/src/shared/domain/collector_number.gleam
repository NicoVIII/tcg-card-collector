import gleam/bool
import gleam/int
import gleam/list
import gleam/order.{type Order}
import gleam/string

// A card's number within its set. Not case-normalised: letters and symbols
// carry meaning ("123a", "★"); canonical form is only trimmed and non-empty.
pub opaque type CollectorNumber {
  CollectorNumber(value: String)
}

pub type CollectorNumberError {
  Empty
  NotCanonical
}

/// Strict constructor — accepts only already-canonical (trimmed) input. Use
/// from_user_input when the value comes from human-supplied text.
pub fn new(raw: String) -> Result(CollectorNumber, CollectorNumberError) {
  use <- bool.guard(raw == "", Error(Empty))
  use <- bool.guard(raw != string.trim(raw), Error(NotCanonical))
  Ok(CollectorNumber(raw))
}

/// Lenient constructor for user-supplied text: trims.
pub fn from_user_input(
  raw: String,
) -> Result(CollectorNumber, CollectorNumberError) {
  new(string.trim(raw))
}

pub fn to_string(number: CollectorNumber) -> String {
  number.value
}

// Collector numbers mix integers with suffixes and symbols ("2", "10", "123a",
// "★"). Compare the leading integer run numerically so "2" < "10", tie-break on
// the full string so "10" < "10a"; a value with a leading int sorts before one
// without (e.g. "123a" < "★"), and two suffix-only values compare as strings.
pub fn compare(left: CollectorNumber, right: CollectorNumber) -> Order {
  case leading_int(left.value), leading_int(right.value) {
    Ok(l), Ok(r) ->
      order.break_tie(
        int.compare(l, r),
        string.compare(left.value, right.value),
      )
    Ok(_), Error(_) -> order.Lt
    Error(_), Ok(_) -> order.Gt
    Error(_), Error(_) -> string.compare(left.value, right.value)
  }
}

fn leading_int(raw: String) -> Result(Int, Nil) {
  raw
  |> string.to_graphemes
  |> list.take_while(is_ascii_digit)
  |> string.join("")
  |> int.parse
}

fn is_ascii_digit(grapheme: String) -> Bool {
  case grapheme {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

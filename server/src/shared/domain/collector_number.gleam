import gleam/int
import gleam/list
import gleam/order.{type Order}
import gleam/string

// Collector numbers mix integers with suffixes and symbols ("2", "10", "123a",
// "★"). Compare the leading integer run numerically so "2" < "10", tie-break on
// the full string so "10" < "10a"; a value with a leading int sorts before one
// without (e.g. "123a" < "★"), and two suffix-only values compare as strings.
pub fn compare(left: String, right: String) -> Order {
  case leading_int(left), leading_int(right) {
    Ok(l), Ok(r) ->
      order.break_tie(int.compare(l, r), string.compare(left, right))
    Ok(_), Error(_) -> order.Lt
    Error(_), Ok(_) -> order.Gt
    Error(_), Error(_) -> string.compare(left, right)
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

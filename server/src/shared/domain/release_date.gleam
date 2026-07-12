import gleam/list
import gleam/order.{type Order}
import gleam/string

// A calendar date as the catalog source publishes it (ISO "YYYY-MM-DD"),
// validated at parse time. Held as the ISO string: lexicographic comparison is
// chronological for this shape, and every seam (SQLite, the wire) wants the
// string form anyway.
pub opaque type ReleaseDate {
  ReleaseDate(iso: String)
}

fn is_digits(value: String, count: Int) -> Bool {
  let graphemes = string.to_graphemes(value)
  list.length(graphemes) == count
  && list.all(graphemes, fn(g) {
    case g {
      "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
      _ -> False
    }
  })
}

pub fn parse(raw: String) -> Result(ReleaseDate, Nil) {
  case string.split(string.trim(raw), "-") {
    [year, month, day] ->
      case is_digits(year, 4) && is_digits(month, 2) && is_digits(day, 2) {
        True -> Ok(ReleaseDate(year <> "-" <> month <> "-" <> day))
        False -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn to_string(date: ReleaseDate) -> String {
  date.iso
}

pub fn compare(left: ReleaseDate, right: ReleaseDate) -> Order {
  string.compare(left.iso, right.iso)
}

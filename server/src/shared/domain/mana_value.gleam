import gleam/float
import gleam/int
import gleam/order.{type Order}
import gleam/string

// A card's mana value (Scryfall's `cmc`; current official Magic vocabulary
// says "mana value" for the same number). Held as a Float, not truncated to
// Int: a handful of Un-set cards have a fractional cost (e.g. 0.5), and 0 is
// a legitimate value (lands) rather than a gap.
pub opaque type ManaValue {
  ManaValue(value: Float)
}

pub fn from_float(value: Float) -> Result(ManaValue, Nil) {
  case value >=. 0.0 {
    True -> Ok(ManaValue(value))
    False -> Error(Nil)
  }
}

// Scryfall's JSON number survives the jq/CSV round trip as a string; jq may
// render a whole number with or without a trailing ".0" depending on version,
// and Gleam's own float.parse rejects "3" outright, so both integral and
// fractional spellings are accepted here.
pub fn parse(raw: String) -> Result(ManaValue, Nil) {
  let trimmed = string.trim(raw)
  case float.parse(trimmed) {
    Ok(value) -> from_float(value)
    Error(Nil) ->
      case int.parse(trimmed) {
        Ok(value) -> from_float(int.to_float(value))
        Error(Nil) -> Error(Nil)
      }
  }
}

pub fn to_string(mana_value: ManaValue) -> String {
  float.to_string(mana_value.value)
}

pub fn compare(left: ManaValue, right: ManaValue) -> Order {
  float.compare(left.value, right.value)
}

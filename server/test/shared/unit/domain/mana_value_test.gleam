import gleam/list
import gleam/order
import shared/domain/mana_value

pub fn parses_integral_and_fractional_values_test() {
  let assert Ok(three) = mana_value.parse("3")
  assert mana_value.to_string(three) == "3.0"

  let assert Ok(half) = mana_value.parse("0.5")
  assert mana_value.to_string(half) == "0.5"

  let assert Ok(zero) = mana_value.parse("0")
  assert mana_value.to_string(zero) == "0.0"
}

pub fn trims_surrounding_whitespace_test() {
  let assert Ok(value) = mana_value.parse(" 3.0 ")
  assert mana_value.to_string(value) == "3.0"
}

pub fn rejects_negative_and_malformed_values_test() {
  let invalid = ["-1", "-0.5", "", "abc", "3.0.0"]
  assert list.all(invalid, fn(raw) { mana_value.parse(raw) == Error(Nil) })
}

pub fn from_float_rejects_negative_test() {
  assert mana_value.from_float(-0.5) == Error(Nil)
  let assert Ok(_) = mana_value.from_float(0.0)
}

pub fn compares_numerically_test() {
  let assert Ok(lower) = mana_value.parse("0.5")
  let assert Ok(higher) = mana_value.parse("4")
  assert mana_value.compare(lower, higher) == order.Lt
  assert mana_value.compare(higher, lower) == order.Gt
  assert mana_value.compare(lower, lower) == order.Eq
}

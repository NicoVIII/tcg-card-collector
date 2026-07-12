import gleam/order
import shared/domain/set_code

pub fn new_accepts_canonical_input_and_round_trips_test() {
  let assert Ok(code) = set_code.new("m11")
  assert set_code.to_string(code) == "m11"
}

pub fn new_rejects_empty_test() {
  assert set_code.new("") == Error(set_code.Empty)
}

pub fn new_rejects_uppercase_test() {
  assert set_code.new("M11") == Error(set_code.NotCanonical)
}

pub fn new_rejects_padding_test() {
  assert set_code.new(" m11") == Error(set_code.NotCanonical)
}

pub fn from_user_input_trims_and_lowercases_test() {
  let assert Ok(code) = set_code.from_user_input("  M11  ")
  assert set_code.to_string(code) == "m11"
}

pub fn from_user_input_rejects_whitespace_only_test() {
  assert set_code.from_user_input("   ") == Error(set_code.Empty)
}

pub fn compares_lexicographically_test() {
  let assert Ok(grn) = set_code.new("grn")
  let assert Ok(lea) = set_code.new("lea")
  assert set_code.compare(grn, lea) == order.Lt
  assert set_code.compare(lea, grn) == order.Gt
  assert set_code.compare(grn, grn) == order.Eq
}

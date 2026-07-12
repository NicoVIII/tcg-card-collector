import gleam/order.{type Order}
import shared/domain/collector_number

pub fn new_accepts_canonical_input_and_round_trips_test() {
  let assert Ok(number) = collector_number.new("123a")
  assert collector_number.to_string(number) == "123a"
}

pub fn new_rejects_empty_test() {
  assert collector_number.new("") == Error(collector_number.Empty)
}

pub fn new_rejects_padding_test() {
  assert collector_number.new(" 146") == Error(collector_number.NotCanonical)
}

pub fn new_preserves_case_test() {
  // Not case-normalised — letters carry meaning
  let assert Ok(number) = collector_number.new("123A")
  assert collector_number.to_string(number) == "123A"
}

pub fn from_user_input_trims_test() {
  let assert Ok(number) = collector_number.from_user_input("  146  ")
  assert collector_number.to_string(number) == "146"
}

pub fn from_user_input_rejects_whitespace_only_test() {
  assert collector_number.from_user_input("   ")
    == Error(collector_number.Empty)
}

// ── compare: numeric-aware physical filing order ──────────────────────────────

pub fn compares_leading_integers_numerically_test() {
  assert compare("2", "10") == order.Lt
}

pub fn breaks_numeric_ties_on_the_full_string_test() {
  assert compare("10", "10a") == order.Lt
}

pub fn numbered_sorts_before_symbol_only_test() {
  assert compare("123a", "★") == order.Lt
}

pub fn symbol_only_values_compare_as_strings_test() {
  // "†" (U+2020) precedes "★" (U+2605) in plain string order
  assert compare("†", "★") == order.Lt
}

pub fn equal_values_compare_equal_test() {
  assert compare("146", "146") == order.Eq
}

fn compare(left: String, right: String) -> Order {
  let assert Ok(l) = collector_number.new(left)
  let assert Ok(r) = collector_number.new(right)
  collector_number.compare(l, r)
}

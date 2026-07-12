import shared/domain/card_key.{InvalidCollectorNumber, InvalidSetCode}
import shared/domain/collector_number
import shared/domain/set_code

// ── new (strict constructor) ──────────────────────────────────────────────────

pub fn new_accepts_lowercase_trimmed_input_test() {
  assert card_key.new(set_code: "m11", collector_number: "146") |> is_ok
}

pub fn new_accepts_canonical_mixed_collector_number_test() {
  // collector_number is not case-normalised — letters and symbols are allowed as-is
  assert card_key.new(set_code: "m11", collector_number: "123a") |> is_ok
}

pub fn new_rejects_uppercase_set_code_test() {
  assert card_key.new(set_code: "M11", collector_number: "146")
    == Error(InvalidSetCode(set_code.NotCanonical))
}

pub fn new_rejects_mixed_case_set_code_test() {
  assert card_key.new(set_code: "m11A", collector_number: "146")
    == Error(InvalidSetCode(set_code.NotCanonical))
}

pub fn new_rejects_padded_set_code_test() {
  assert card_key.new(set_code: " m11", collector_number: "146")
    == Error(InvalidSetCode(set_code.NotCanonical))
}

pub fn new_rejects_padded_collector_number_test() {
  assert card_key.new(set_code: "m11", collector_number: " 146")
    == Error(InvalidCollectorNumber(collector_number.NotCanonical))
}

pub fn new_rejects_empty_set_code_test() {
  assert card_key.new(set_code: "", collector_number: "146")
    == Error(InvalidSetCode(set_code.Empty))
}

pub fn new_rejects_empty_collector_number_test() {
  assert card_key.new(set_code: "m11", collector_number: "")
    == Error(InvalidCollectorNumber(collector_number.Empty))
}

// ── from_user_input (lenient constructor) ─────────────────────────────────────

pub fn from_user_input_lowercases_set_code_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "M11", collector_number: "146")
  assert card_key.set_code_string(key) == "m11"
}

pub fn from_user_input_trims_set_code_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "  m11  ", collector_number: "146")
  assert card_key.set_code_string(key) == "m11"
}

pub fn from_user_input_trims_collector_number_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "m11", collector_number: " 146 ")
  assert card_key.collector_number_string(key) == "146"
}

pub fn from_user_input_preserves_collector_number_case_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "m11", collector_number: "123A")
  assert card_key.collector_number_string(key) == "123A"
}

pub fn from_user_input_both_upper_and_padded_test() {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "  M11  ", collector_number: "  146  ")
  assert card_key.set_code_string(key) == "m11"
  assert card_key.collector_number_string(key) == "146"
}

pub fn from_user_input_rejects_whitespace_only_set_code_test() {
  assert card_key.from_user_input(set_code: "   ", collector_number: "146")
    == Error(InvalidSetCode(set_code.Empty))
}

pub fn from_user_input_rejects_empty_collector_number_test() {
  assert card_key.from_user_input(set_code: "m11", collector_number: "")
    == Error(InvalidCollectorNumber(collector_number.Empty))
}

// ── accessors ─────────────────────────────────────────────────────────────────

pub fn accessors_return_the_component_value_objects_test() {
  let assert Ok(key) = card_key.new(set_code: "m11", collector_number: "146")
  assert card_key.set_code(key) |> set_code.to_string == "m11"
  assert card_key.collector_number(key) |> collector_number.to_string == "146"
}

// ── helpers ───────────────────────────────────────────────────────────────────

fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

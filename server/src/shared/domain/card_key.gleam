import gleam/result
import shared/domain/collector_number.{
  type CollectorNumber, type CollectorNumberError,
} as collector_number_value
import shared/domain/set_code.{type SetCode, type SetCodeError} as set_code_value

// Which component failed and why; the component types own the validation
// vocabulary.
pub type CardKeyError {
  InvalidSetCode(SetCodeError)
  InvalidCollectorNumber(CollectorNumberError)
}

pub opaque type CardKey {
  CardKey(set_code: SetCode, collector_number: CollectorNumber)
}

pub fn set_code(key: CardKey) -> SetCode {
  key.set_code
}

pub fn collector_number(key: CardKey) -> CollectorNumber {
  key.collector_number
}

pub fn set_code_string(key: CardKey) -> String {
  set_code_value.to_string(key.set_code)
}

pub fn collector_number_string(key: CardKey) -> String {
  collector_number_value.to_string(key.collector_number)
}

/// Strict constructor — accepts only already-canonical input.
/// set_code must be trimmed and lowercase; collector_number must be trimmed.
/// Use from_user_input when the values come from human-supplied text.
pub fn new(
  set_code raw_set_code: String,
  collector_number raw_collector_number: String,
) -> Result(CardKey, CardKeyError) {
  use set_code <- result.try(
    set_code_value.new(raw_set_code) |> result.map_error(InvalidSetCode),
  )
  use collector_number <- result.try(
    collector_number_value.new(raw_collector_number)
    |> result.map_error(InvalidCollectorNumber),
  )
  Ok(CardKey(set_code:, collector_number:))
}

/// Lenient constructor for user-supplied text.
/// Trims both fields and lowercases set_code before validating.
pub fn from_user_input(
  set_code raw_set_code: String,
  collector_number raw_collector_number: String,
) -> Result(CardKey, CardKeyError) {
  use set_code <- result.try(
    set_code_value.from_user_input(raw_set_code)
    |> result.map_error(InvalidSetCode),
  )
  use collector_number <- result.try(
    collector_number_value.from_user_input(raw_collector_number)
    |> result.map_error(InvalidCollectorNumber),
  )
  Ok(CardKey(set_code:, collector_number:))
}

/// Human-readable description of a validation failure, for error reporting
/// at parse boundaries.
pub fn describe_error(error: CardKeyError) -> String {
  case error {
    InvalidSetCode(set_code_value.Empty) -> "empty set_code"
    InvalidSetCode(set_code_value.NotCanonical) -> "set_code not canonical"
    InvalidCollectorNumber(collector_number_value.Empty) ->
      "empty collector_number"
    InvalidCollectorNumber(collector_number_value.NotCanonical) ->
      "collector_number not canonical"
  }
}

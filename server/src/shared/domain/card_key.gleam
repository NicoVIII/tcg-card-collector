import gleam/bool
import gleam/result
import gleam/string
import shared/domain/non_empty_string.{type NonEmptyString}

pub type CardKey {
  CardKey(set_code: NonEmptyString, collector_number: NonEmptyString)
}

pub type CardKeyError {
  EmptySetCode
  EmptyCollectorNumber
  // set_code must be trimmed and lowercase
  SetCodeNotCanonical
  // collector_number must be trimmed
  CollectorNumberNotCanonical
}

pub fn set_code_string(key: CardKey) -> String {
  non_empty_string.to_string(key.set_code)
}

pub fn collector_number_string(key: CardKey) -> String {
  non_empty_string.to_string(key.collector_number)
}

fn is_canonical_set_code(s: String) -> Bool {
  s == string.trim(s) && s == string.lowercase(s)
}

fn is_trimmed(s: String) -> Bool {
  s == string.trim(s)
}

/// Strict constructor — accepts only already-canonical input.
/// set_code must be trimmed and lowercase; collector_number must be trimmed.
/// Use from_user_input when the values come from human-supplied text.
pub fn new(
  set_code set_code: String,
  collector_number collector_number: String,
) -> Result(CardKey, CardKeyError) {
  use set_code_nes <- result.try(
    non_empty_string.new(set_code) |> result.map_error(fn(_) { EmptySetCode }),
  )
  use <- bool.guard(
    !is_canonical_set_code(set_code),
    Error(SetCodeNotCanonical),
  )
  use collector_number_nes <- result.try(
    non_empty_string.new(collector_number)
    |> result.map_error(fn(_) { EmptyCollectorNumber }),
  )
  use <- bool.guard(
    !is_trimmed(collector_number),
    Error(CollectorNumberNotCanonical),
  )
  Ok(CardKey(set_code: set_code_nes, collector_number: collector_number_nes))
}

/// Lenient constructor for user-supplied text.
/// Trims both fields and lowercases set_code before delegating to new.
pub fn from_user_input(
  set_code set_code: String,
  collector_number collector_number: String,
) -> Result(CardKey, CardKeyError) {
  new(
    set_code: set_code |> string.trim |> string.lowercase,
    collector_number: collector_number |> string.trim,
  )
}

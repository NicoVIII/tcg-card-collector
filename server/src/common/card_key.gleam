import common/non_empty_string.{type NonEmptyString}
import gleam/result

pub type CardKey {
  CardKey(set_code: NonEmptyString, collector_number: NonEmptyString)
}

pub type CardKeyError {
  EmptySetCode
  EmptyCollectorNumber
}

pub fn new(
  set_code set_code: String,
  collector_number collector_number: String,
) -> Result(CardKey, CardKeyError) {
  use set_code <- result.try(
    non_empty_string.new(set_code) |> result.map_error(fn(_) { EmptySetCode }),
  )
  use collector_number <- result.try(
    non_empty_string.new(collector_number)
    |> result.map_error(fn(_) { EmptyCollectorNumber }),
  )
  Ok(CardKey(set_code: set_code, collector_number: collector_number))
}

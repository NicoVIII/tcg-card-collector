import gleam/bool

pub opaque type NonEmptyString {
  NonEmptyString(value: String)
}

pub fn new(value: String) -> Result(NonEmptyString, Nil) {
  use <- bool.guard(value == "", Error(Nil))

  Ok(NonEmptyString(value))
}

pub fn to_string(non_empty_string: NonEmptyString) -> String {
  non_empty_string.value
}

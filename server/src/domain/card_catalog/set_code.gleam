import gleam/string

pub opaque type SetCode {
  SetCode(value: String)
}

pub type SetCodeError {
  EmptySetCode
  SetCodeTooLong
}

pub fn new(value: String) -> Result(SetCode, SetCodeError) {
  case string.length(value) == 0 {
    True -> Error(EmptySetCode)
    False ->
      case string.length(value) > 16 {
        True -> Error(SetCodeTooLong)
        False -> Ok(SetCode(value))
      }
  }
}

pub fn value(set_code: SetCode) -> String {
  let SetCode(value) = set_code
  value
}

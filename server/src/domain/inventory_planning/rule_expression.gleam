import gleam/string

pub type RuleExpression {
  SetCodeEquals(set_code: String)
}

pub type ParseError {
  EmptyValue
  UnknownForm
}

pub fn parse(raw: String) -> Result(RuleExpression, ParseError) {
  case string.split(raw, "=") {
    ["set_code", value] ->
      case string.length(value) > 0 {
        True -> Ok(SetCodeEquals(set_code: value))
        False -> Error(EmptyValue)
      }
    _ -> Error(UnknownForm)
  }
}

pub fn to_string(expr: RuleExpression) -> String {
  case expr {
    SetCodeEquals(set_code: code) -> "set_code=" <> code
  }
}

pub fn matches(expr: RuleExpression, set_code: String) -> Bool {
  case expr {
    SetCodeEquals(set_code: code) -> code == set_code
  }
}

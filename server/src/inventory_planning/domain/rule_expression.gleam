import gleam/string
import shared/domain/non_empty_string.{type NonEmptyString}

pub type RuleExpression {
  SetCodeEquals(set_code: NonEmptyString)
}

pub type ParseError {
  EmptyValue
  UnknownForm
}

pub fn parse(raw: String) -> Result(RuleExpression, ParseError) {
  case string.split(raw, "=") {
    ["set_code", value] ->
      case non_empty_string.new(value) {
        Ok(nes) -> Ok(SetCodeEquals(set_code: nes))
        Error(_) -> Error(EmptyValue)
      }
    _ -> Error(UnknownForm)
  }
}

pub fn to_string(expr: RuleExpression) -> String {
  case expr {
    SetCodeEquals(set_code: code) ->
      "set_code=" <> non_empty_string.to_string(code)
  }
}

pub fn matches(expr: RuleExpression, set_code: String) -> Bool {
  case expr {
    SetCodeEquals(set_code: code) ->
      non_empty_string.to_string(code) == set_code
  }
}

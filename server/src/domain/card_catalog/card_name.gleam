import gleam/string

pub opaque type CardName {
  CardName(value: String)
}

pub type CardNameError {
  EmptyCardName
}

pub fn new(value: String) -> Result(CardName, CardNameError) {
  case string.length(value) == 0 {
    True -> Error(EmptyCardName)
    False -> Ok(CardName(value))
  }
}

pub fn value(card_name: CardName) -> String {
  let CardName(value) = card_name
  value
}

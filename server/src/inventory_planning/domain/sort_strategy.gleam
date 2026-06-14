pub type SortStrategy {
  ByCardName
  BySetCode
  ByQuantity
}

pub type SortStrategyError {
  UnknownSortStrategy
}

pub fn parse(raw: String) -> Result(SortStrategy, SortStrategyError) {
  case raw {
    "card_name" -> Ok(ByCardName)
    "set_code" -> Ok(BySetCode)
    "quantity" -> Ok(ByQuantity)
    _ -> Error(UnknownSortStrategy)
  }
}

pub fn to_string(strategy: SortStrategy) -> String {
  case strategy {
    ByCardName -> "card_name"
    BySetCode -> "set_code"
    ByQuantity -> "quantity"
  }
}

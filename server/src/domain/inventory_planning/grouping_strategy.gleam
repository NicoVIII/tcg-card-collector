pub type GroupingStrategy {
  ByLocation
  BySet
  ByCardName
}

pub type GroupingStrategyError {
  UnknownGroupingStrategy
}

pub fn parse(raw: String) -> Result(GroupingStrategy, GroupingStrategyError) {
  case raw {
    "location" -> Ok(ByLocation)
    "set_code" -> Ok(BySet)
    "card_name" -> Ok(ByCardName)
    _ -> Error(UnknownGroupingStrategy)
  }
}

pub fn to_string(strategy: GroupingStrategy) -> String {
  case strategy {
    ByLocation -> "location"
    BySet -> "set_code"
    ByCardName -> "card_name"
  }
}

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
    "by_location" -> Ok(ByLocation)
    "by_set" -> Ok(BySet)
    "by_card_name" -> Ok(ByCardName)
    _ -> Error(UnknownGroupingStrategy)
  }
}

pub fn to_string(strategy: GroupingStrategy) -> String {
  case strategy {
    ByLocation -> "by_location"
    BySet -> "by_set"
    ByCardName -> "by_card_name"
  }
}

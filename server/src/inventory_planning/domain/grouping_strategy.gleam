pub type GroupingStrategy {
  ByLocation
  BySet
}

pub type GroupingStrategyError {
  UnknownGroupingStrategy
}

pub fn parse(raw: String) -> Result(GroupingStrategy, GroupingStrategyError) {
  case raw {
    "location_name" -> Ok(ByLocation)
    "set_code" -> Ok(BySet)
    _ -> Error(UnknownGroupingStrategy)
  }
}

pub fn to_string(strategy: GroupingStrategy) -> String {
  case strategy {
    ByLocation -> "location_name"
    BySet -> "set_code"
  }
}

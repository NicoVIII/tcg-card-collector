pub type ReplaceTargetSetsPort {
  ReplaceTargetSetsPort(replace: fn(List(String)) -> Result(Nil, String))
}

pub type ReplaceTargetSetsError {
  InvalidSetCodes
  PersistenceFailed(reason: String)
}

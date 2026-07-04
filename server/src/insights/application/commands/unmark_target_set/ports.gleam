pub type UnmarkTargetSetPort {
  UnmarkTargetSetPort(unmark: fn(String) -> Result(Nil, String))
}

pub type UnmarkTargetSetError {
  InvalidSetCode
  PersistenceFailed(reason: String)
}

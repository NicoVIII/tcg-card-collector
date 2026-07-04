pub type MarkTargetSetPort {
  MarkTargetSetPort(mark: fn(String) -> Result(Nil, String))
}

pub type MarkTargetSetError {
  InvalidSetCode
  PersistenceFailed(reason: String)
}

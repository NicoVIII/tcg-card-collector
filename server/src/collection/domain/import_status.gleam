pub type ImportStatus {
  Pending
  Running
  Succeeded
  Failed
}

pub fn to_string(status: ImportStatus) -> String {
  case status {
    Pending -> "pending"
    Running -> "running"
    Succeeded -> "succeeded"
    Failed -> "failed"
  }
}

pub fn from_string(raw: String) -> Result(ImportStatus, Nil) {
  case raw {
    "pending" -> Ok(Pending)
    "running" -> Ok(Running)
    "succeeded" -> Ok(Succeeded)
    "failed" -> Ok(Failed)
    _ -> Error(Nil)
  }
}

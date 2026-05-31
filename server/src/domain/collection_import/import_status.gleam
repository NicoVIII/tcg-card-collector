pub type ImportStatus {
  Pending
  Running
  Succeeded
  Failed
}

pub type ImportStatusError {
  UnknownImportStatus
}

pub fn parse(raw: String) -> Result(ImportStatus, ImportStatusError) {
  case raw {
    "pending" -> Ok(Pending)
    "running" -> Ok(Running)
    "succeeded" -> Ok(Succeeded)
    "failed" -> Ok(Failed)
    _ -> Error(UnknownImportStatus)
  }
}

pub fn to_string(status: ImportStatus) -> String {
  case status {
    Pending -> "pending"
    Running -> "running"
    Succeeded -> "succeeded"
    Failed -> "failed"
  }
}

pub fn can_transition(
  from from_status: ImportStatus,
  to to_status: ImportStatus,
) -> Bool {
  case from_status, to_status {
    Pending, Running -> True
    Running, Succeeded -> True
    Running, Failed -> True
    _, _ -> False
  }
}

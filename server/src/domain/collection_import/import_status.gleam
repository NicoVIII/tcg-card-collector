pub type ImportStatus {
  Pending
  Running
  Succeeded
  Failed
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

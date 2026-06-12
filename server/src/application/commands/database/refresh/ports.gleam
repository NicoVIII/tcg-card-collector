pub type RefreshDatabasePort {
  RefreshDatabasePort(execute: fn() -> Result(Nil, RefreshDatabaseError))
}

pub type RefreshDatabaseError {
  RefreshDatabaseError(message: String)
}

import inventory_planning/domain/managed_location.{type ManagedLocation}

pub type RenameManagedLocationPorts {
  RenameManagedLocationPorts(
    list_locations: fn() -> Result(List(ManagedLocation), String),
    rename: fn(String, String) -> Result(Nil, String),
  )
}

pub type RenameManagedLocationError {
  InvalidName
  UnknownLocation
  DuplicateName
  PersistenceFailed(reason: String)
}

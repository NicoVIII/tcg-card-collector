import inventory_planning/domain/managed_location.{type ManagedLocation}

pub type DeleteManagedLocationPorts {
  DeleteManagedLocationPorts(
    list_locations: fn() -> Result(List(ManagedLocation), String),
    /// Removes the location, its members, and its placed-ledger rows
    /// together.
    delete: fn(String) -> Result(Nil, String),
  )
}

pub type DeleteManagedLocationError {
  UnknownLocation
  PersistenceFailed(reason: String)
}

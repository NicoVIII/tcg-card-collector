import inventory_planning/domain/managed_location.{type ManagedLocation}

pub type ListManagedLocationsPort =
  fn() -> Result(List(ManagedLocation), String)

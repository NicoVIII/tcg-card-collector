import inventory_planning/domain/managed_location.{
  type ManagedLocation, type MemberDelta, type Underheld,
}

pub type RemoveFromManagedLocationPorts {
  RemoveFromManagedLocationPorts(
    list_locations: fn() -> Result(List(ManagedLocation), String),
    decrement_members: fn(String, List(MemberDelta)) -> Result(Nil, String),
  )
}

pub type RemoveFromManagedLocationError {
  UnknownLocation
  InvalidCopies
  NotHeld(Underheld)
  PersistenceFailed(reason: String)
}

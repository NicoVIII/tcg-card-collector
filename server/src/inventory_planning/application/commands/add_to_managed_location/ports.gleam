import gleam/dict.{type Dict}
import inventory_planning/domain/managed_location.{
  type ManagedLocation, type MemberDelta, type Overclaim,
}
import shared/domain/copy_key.{type CopyKey}

pub type AddToManagedLocationPorts {
  AddToManagedLocationPorts(
    list_locations: fn() -> Result(List(ManagedLocation), String),
    owned_quantities: fn() -> Result(Dict(CopyKey, Int), String),
    increment_members: fn(String, List(MemberDelta)) -> Result(Nil, String),
  )
}

pub type AddToManagedLocationError {
  UnknownLocation
  InvalidCopies
  NotEnoughOwned(Overclaim)
  PersistenceFailed(reason: String)
}

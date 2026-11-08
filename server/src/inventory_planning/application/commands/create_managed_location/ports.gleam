import inventory_planning/domain/managed_location.{
  type ManagedLocation, type ManagedLocationKind,
}

pub type ManagedLocationWriteModel {
  ManagedLocationWriteModel(id: String, name: String, kind: ManagedLocationKind)
}

pub type CreateManagedLocationPorts {
  CreateManagedLocationPorts(
    list_locations: fn() -> Result(List(ManagedLocation), String),
    insert: fn(ManagedLocationWriteModel) -> Result(Nil, String),
  )
}

pub type CreateManagedLocationError {
  InvalidId
  InvalidName
  InvalidKind
  DuplicateId
  DuplicateName
  PersistenceFailed(reason: String)
}

pub type BulkSpecWriteModel {
  BulkSpecWriteModel(location_name: String, sort_keys: String)
}

pub type UpdateBulkSpecPort {
  UpdateBulkSpecPort(update: fn(BulkSpecWriteModel) -> Result(Nil, String))
}

pub type UpdateBulkSpecError {
  InvalidLocationName
  InvalidSortKeys
  PersistenceFailed(reason: String)
}

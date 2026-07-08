pub type BulkSpecReadModel {
  BulkSpecReadModel(location_name: String, sort_keys: String)
}

pub type GetBulkSpecPort {
  GetBulkSpecPort(current: fn() -> Result(BulkSpecReadModel, String))
}

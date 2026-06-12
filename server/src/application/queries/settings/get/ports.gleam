pub type AppSettingsReadModel {
  AppSettingsReadModel(default_sort: String, default_grouping: String)
}

pub type GetSettingsPort {
  GetSettingsPort(current: fn() -> AppSettingsReadModel)
}

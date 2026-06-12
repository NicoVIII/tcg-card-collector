pub type AppSettingsWriteModel {
  AppSettingsWriteModel(default_sort: String, default_grouping: String)
}

pub type UpdateSettingsPort {
  UpdateSettingsPort(update: fn(AppSettingsWriteModel) -> Nil)
}

pub type UpdateSettingsError {
  UpdateSettingsError(message: String)
}

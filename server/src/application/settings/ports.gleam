pub type AppSettingsReadModel {
  AppSettingsReadModel(default_sort: String, default_grouping: String)
}

pub type AppSettingsWriteModel {
  AppSettingsWriteModel(default_sort: String, default_grouping: String)
}

pub type SettingsRepository {
  SettingsRepository(
    get_settings: fn() -> AppSettingsReadModel,
    update_settings: fn(AppSettingsWriteModel) -> Nil,
  )
}

pub fn current(repository: SettingsRepository) -> AppSettingsReadModel {
  let SettingsRepository(get_settings: get_settings, ..) = repository
  get_settings()
}

pub fn update(
  repository: SettingsRepository,
  settings: AppSettingsWriteModel,
) -> Nil {
  let SettingsRepository(update_settings: update_settings, ..) = repository
  update_settings(settings)
}

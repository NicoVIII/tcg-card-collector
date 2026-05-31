import application/settings/ports

pub fn get_settings(
  repository: ports.SettingsRepository,
) -> ports.AppSettingsReadModel {
  ports.current(repository)
}

pub fn update_settings(
  repository: ports.SettingsRepository,
  settings: ports.AppSettingsWriteModel,
) -> Nil {
  ports.update(repository, settings)
}

import application/settings/ports
import driver/skir/settings_handler

pub fn get_settings(
  repository: ports.SettingsRepository,
) -> ports.AppSettingsReadModel {
  settings_handler.get_settings(repository)
}

pub fn update_settings(
  repository: ports.SettingsRepository,
  request: settings_handler.UpdateSettingsRequest,
) -> Nil {
  settings_handler.update_settings(repository, request)
}

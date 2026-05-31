import application/settings/ports
import application/settings/service

pub type UpdateSettingsRequest {
  UpdateSettingsRequest(default_sort: String, default_grouping: String)
}

pub fn get_settings(
  repository: ports.SettingsRepository,
) -> ports.AppSettingsReadModel {
  service.get_settings(repository)
}

pub fn update_settings(
  repository: ports.SettingsRepository,
  request: UpdateSettingsRequest,
) -> Nil {
  let UpdateSettingsRequest(
    default_sort: default_sort,
    default_grouping: default_grouping,
  ) = request

  service.update_settings(
    repository,
    ports.AppSettingsWriteModel(default_sort:, default_grouping:),
  )
}

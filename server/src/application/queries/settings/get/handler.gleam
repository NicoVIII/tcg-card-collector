import application/queries/settings/get/ports

pub type GetSettingsQuery {
  GetSettingsQuery
}

pub fn execute(
  _query: GetSettingsQuery,
  port: ports.GetSettingsPort,
) -> ports.AppSettingsReadModel {
  port.current()
}

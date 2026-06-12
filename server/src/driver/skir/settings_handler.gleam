import application/commands/settings/update/handler as update_settings_handler
import application/commands/settings/update/ports as update_settings_ports
import application/queries/settings/get/handler as get_settings_handler
import application/queries/settings/get/ports as get_settings_ports

pub fn get_settings(
  port: get_settings_ports.GetSettingsPort,
) -> get_settings_ports.AppSettingsReadModel {
  get_settings_handler.execute(get_settings_handler.GetSettingsQuery, port)
}

pub fn update_settings(
  port: update_settings_ports.UpdateSettingsPort,
  default_sort: String,
  default_grouping: String,
) -> Nil {
  let _ =
    update_settings_handler.execute(
      update_settings_handler.UpdateSettingsCommand(
        default_sort: default_sort,
        default_grouping: default_grouping,
      ),
      port,
    )
  Nil
}

import application/commands/settings/update/ports
import infrastructure/stores/settings/settings_store

pub fn new() -> ports.UpdateSettingsPort {
  ports.UpdateSettingsPort(update: fn(settings) {
    let ports.AppSettingsWriteModel(
      default_sort: default_sort,
      default_grouping: default_grouping,
    ) = settings
    settings_store.update(default_sort, default_grouping)
  })
}

import application/queries/settings/get/ports
import infrastructure/stores/settings/settings_store

pub fn new() -> ports.GetSettingsPort {
  ports.GetSettingsPort(current: fn() {
    let #(default_sort, default_grouping) = settings_store.get()
    ports.AppSettingsReadModel(default_sort:, default_grouping:)
  })
}

import application/settings/ports
import infrastructure/settings/settings_store

pub fn new() -> ports.SettingsRepository {
  ports.SettingsRepository(
    get_settings: fn() {
      let #(default_sort, default_grouping) = settings_store.get()
      ports.AppSettingsReadModel(default_sort:, default_grouping:)
    },
    update_settings: fn(settings) {
      let ports.AppSettingsWriteModel(
        default_sort: default_sort,
        default_grouping: default_grouping,
      ) = settings

      settings_store.update(default_sort, default_grouping)
    },
  )
}

pub fn reset_for_tests() -> Nil {
  settings_store.clear()
}

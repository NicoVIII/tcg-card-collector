import application/settings/ports

pub fn new() -> ports.SettingsRepository {
  ports.SettingsRepository(
    get_settings: fn() {
      ports.AppSettingsReadModel(
        default_sort: "card_name",
        default_grouping: "location",
      )
    },
    update_settings: fn(_settings) { Nil },
  )
}

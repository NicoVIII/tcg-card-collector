import application/settings/ports

@external(erlang, "settings_store", "get")
fn get_from_store() -> #(String, String)

@external(erlang, "settings_store", "update")
fn update_in_store(default_sort: String, default_grouping: String) -> Nil

@external(erlang, "settings_store", "clear")
fn clear_store() -> Nil

pub fn new() -> ports.SettingsRepository {
  ports.SettingsRepository(
    get_settings: fn() {
      let #(default_sort, default_grouping) = get_from_store()
      ports.AppSettingsReadModel(default_sort:, default_grouping:)
    },
    update_settings: fn(settings) {
      let ports.AppSettingsWriteModel(
        default_sort: default_sort,
        default_grouping: default_grouping,
      ) = settings

      update_in_store(default_sort, default_grouping)
    },
  )
}

pub fn reset_for_tests() -> Nil {
  clear_store()
}

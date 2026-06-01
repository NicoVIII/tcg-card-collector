import gleam/string
import infrastructure/sqlite_store

const default_sort = "card_name"

const default_grouping = "location_name"

pub fn get() -> #(String, String) {
  let output =
    sqlite_store.query(
      "SELECT default_sort, default_grouping "
      <> "FROM app_settings WHERE id = 1 LIMIT 1;",
    )

  let trimmed = string.trim(output)
  case trimmed == "" {
    True -> #(default_sort, default_grouping)
    False ->
      case string.split(trimmed, "\t") {
        [sort, grouping] -> #(sort, grouping)
        _ -> #(default_sort, default_grouping)
      }
  }
}

pub fn update(default_sort: String, default_grouping: String) -> Nil {
  let sql =
    "INSERT INTO app_settings (id, default_sort, default_grouping, updated_at) VALUES ("
    <> "1, "
    <> sqlite_store.quote(default_sort)
    <> ", "
    <> sqlite_store.quote(default_grouping)
    <> ", CURRENT_TIMESTAMP"
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  default_sort = excluded.default_sort,"
    <> "  default_grouping = excluded.default_grouping,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql)
}

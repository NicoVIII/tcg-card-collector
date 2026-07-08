import gleam/dynamic/decode
import gleam/result
import shared/infrastructure/stores/sqlite_store
import sqlight

const default_sort = "card_name"

const default_grouping = "location_name"

fn preferences_row_decoder() {
  use sort <- decode.field(0, decode.string)
  use grouping <- decode.field(1, decode.string)
  decode.success(#(sort, grouping))
}

// A query error is a genuine read failure and propagates; only the empty-rows
// case falls back to the seeded defaults.
pub fn get() -> Result(#(String, String), String) {
  use rows <- result.map(
    sqlite_store.query(
      "SELECT default_sort, default_grouping "
        <> "FROM app_settings WHERE id = 1 LIMIT 1;",
      [],
      preferences_row_decoder(),
    )
    |> result.map_error(fn(error) { error.message }),
  )
  case rows {
    [row, ..] -> row
    [] -> #(default_sort, default_grouping)
  }
}

pub fn update(
  default_sort: String,
  default_grouping: String,
) -> Result(Nil, String) {
  let sql =
    "INSERT INTO app_settings (id, default_sort, default_grouping, updated_at) VALUES ("
    <> "1, ?, ?, CURRENT_TIMESTAMP) "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  default_sort = excluded.default_sort,"
    <> "  default_grouping = excluded.default_grouping,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql, [
    sqlight.text(default_sort),
    sqlight.text(default_grouping),
  ])
  |> result.map_error(fn(error) { error.message })
}

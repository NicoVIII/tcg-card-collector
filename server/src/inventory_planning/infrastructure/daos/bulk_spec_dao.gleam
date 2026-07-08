import gleam/dynamic/decode
import gleam/result
import shared/infrastructure/stores/sqlite_store
import sqlight

const default_location_name = "Bulk"

const default_sort_keys = "color_identity,type,name"

fn bulk_spec_row_decoder() {
  use location_name <- decode.field(0, decode.string)
  use sort_keys <- decode.field(1, decode.string)
  decode.success(#(location_name, sort_keys))
}

// Returns the seeded defaults when the singleton row is somehow missing, so the
// cascade always has a bulk location to fall back on. A query *error* is a
// genuine read failure and propagates — only the empty-rows case defaults.
pub fn get() -> Result(#(String, String), String) {
  use rows <- result.map(
    sqlite_store.query(
      "SELECT location_name, sort_keys "
        <> "FROM inventory_bulk_spec WHERE id = 1 LIMIT 1;",
      [],
      bulk_spec_row_decoder(),
    )
    |> result.map_error(fn(error) { error.message }),
  )
  case rows {
    [row, ..] -> row
    [] -> #(default_location_name, default_sort_keys)
  }
}

pub fn update(location_name: String, sort_keys: String) -> Result(Nil, String) {
  let sql =
    "INSERT INTO inventory_bulk_spec (id, location_name, sort_keys, updated_at) VALUES ("
    <> "1, ?, ?, CURRENT_TIMESTAMP) "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  location_name = excluded.location_name,"
    <> "  sort_keys = excluded.sort_keys,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql, [
    sqlight.text(location_name),
    sqlight.text(sort_keys),
  ])
  |> result.map_error(fn(error) { error.message })
}

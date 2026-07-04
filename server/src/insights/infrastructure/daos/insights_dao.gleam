import gleam/dynamic/decode
import gleam/result
import shared/infrastructure/stores/sqlite_store
import sqlight

pub fn mark(set_code: String) -> Result(Nil, String) {
  sqlite_store.exec(
    "INSERT INTO target_sets (set_code) VALUES (?) "
      <> "ON CONFLICT(set_code) DO NOTHING;",
    [sqlight.text(set_code)],
  )
  |> result.map_error(fn(error) { error.message })
}

pub fn unmark(set_code: String) -> Result(Nil, String) {
  sqlite_store.exec("DELETE FROM target_sets WHERE set_code = ?;", [
    sqlight.text(set_code),
  ])
  |> result.map_error(fn(error) { error.message })
}

fn set_code_decoder() {
  use set_code <- decode.field(0, decode.string)
  decode.success(set_code)
}

pub fn list() -> List(String) {
  sqlite_store.query(
    "SELECT set_code FROM target_sets ORDER BY set_code ASC;",
    [],
    set_code_decoder(),
  )
  |> result.unwrap([])
}

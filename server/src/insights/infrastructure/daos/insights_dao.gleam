import gleam/dynamic/decode
import gleam/list
import shared/infrastructure/stores/sqlite_store
import sqlight

pub fn mark(set_code: String) -> Result(Nil, String) {
  sqlite_store.exec(
    "INSERT INTO target_sets (set_code) VALUES (?) "
      <> "ON CONFLICT(set_code) DO NOTHING;",
    [sqlight.text(set_code)],
  )
}

pub fn unmark(set_code: String) -> Result(Nil, String) {
  sqlite_store.exec("DELETE FROM target_sets WHERE set_code = ?;", [
    sqlight.text(set_code),
  ])
}

fn set_code_decoder() -> decode.Decoder(String) {
  use set_code <- decode.field(0, decode.string)
  decode.success(set_code)
}

pub fn list() -> Result(List(String), String) {
  sqlite_store.query(
    "SELECT set_code FROM target_sets ORDER BY set_code ASC;",
    [],
    set_code_decoder(),
  )
}

/// Replaces every target set at once, atomically (Portability's restore,
/// ADR 0019) — mark/unmark stay the one-at-a-time API the UI uses.
pub fn replace(set_codes: List(String)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically([
    #("DELETE FROM target_sets;", []),
    ..list.map(set_codes, insert_statement)
  ])
}

fn insert_statement(set_code: String) -> #(String, List(sqlight.Value)) {
  #("INSERT INTO target_sets (set_code) VALUES (?);", [sqlight.text(set_code)])
}

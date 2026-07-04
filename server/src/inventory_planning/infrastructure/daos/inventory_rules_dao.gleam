import gleam/dynamic/decode
import gleam/result
import shared/infrastructure/stores/sqlite_store
import sqlight

type RuleTuple =
  #(String, String, String, Int, String)

pub fn upsert(
  id: String,
  location_name: String,
  expression: String,
  position: Int,
  selector: String,
) -> Result(Nil, String) {
  let sql =
    "INSERT INTO inventory_rules (id, location_name, expression, position, selector) "
    <> "VALUES (?, ?, ?, ?, ?) "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  location_name = excluded.location_name,"
    <> "  expression = excluded.expression,"
    <> "  position = excluded.position,"
    <> "  selector = excluded.selector,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql, [
    sqlight.text(id),
    sqlight.text(location_name),
    sqlight.text(expression),
    sqlight.int(position),
    sqlight.text(selector),
  ])
  |> result.map_error(fn(error) { error.message })
}

fn rule_row_decoder() {
  use id <- decode.field(0, decode.string)
  use location_name <- decode.field(1, decode.string)
  use expression <- decode.field(2, decode.string)
  use position <- decode.field(3, decode.int)
  use selector <- decode.field(4, decode.string)
  decode.success(#(id, location_name, expression, position, selector))
}

pub fn list() -> List(RuleTuple) {
  sqlite_store.query(
    "SELECT id, location_name, expression, position, selector "
      <> "FROM inventory_rules "
      <> "ORDER BY position ASC, id ASC;",
    [],
    rule_row_decoder(),
  )
  |> result.unwrap([])
}

pub fn delete(id: String) -> Result(Nil, String) {
  sqlite_store.exec("DELETE FROM inventory_rules WHERE id = ?;", [
    sqlight.text(id),
  ])
  |> result.map_error(fn(error) { error.message })
}

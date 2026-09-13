import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import sqlight

pub type RuleRow {
  RuleRow(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
    sort_keys: String,
  )
}

pub fn upsert(row: RuleRow) -> Result(Nil, String) {
  let sql =
    "INSERT INTO inventory_rules (id, location_name, expression, position, selector, sort_keys) "
    <> "VALUES (?, ?, ?, ?, ?, ?) "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  location_name = excluded.location_name,"
    <> "  expression = excluded.expression,"
    <> "  position = excluded.position,"
    <> "  selector = excluded.selector,"
    <> "  sort_keys = excluded.sort_keys,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql, [
    sqlight.text(row.id),
    sqlight.text(row.location_name),
    sqlight.text(row.expression),
    sqlight.int(row.position),
    sqlight.text(row.selector),
    sqlight.text(row.sort_keys),
  ])
}

fn rule_row_decoder() -> decode.Decoder(RuleRow) {
  use id <- decode.field(0, decode.string)
  use location_name <- decode.field(1, decode.string)
  use expression <- decode.field(2, decode.string)
  use position <- decode.field(3, decode.int)
  use selector <- decode.field(4, decode.string)
  use sort_keys <- decode.field(5, decode.string)
  decode.success(RuleRow(
    id:,
    location_name:,
    expression:,
    position:,
    selector:,
    sort_keys:,
  ))
}

pub fn list() -> Result(List(RuleRow), String) {
  sqlite_store.query(
    "SELECT id, location_name, expression, position, selector, sort_keys "
      <> "FROM inventory_rules "
      <> "ORDER BY position ASC, id ASC;",
    [],
    rule_row_decoder(),
  )
}

pub fn delete(id: String) -> Result(Nil, String) {
  sqlite_store.exec("DELETE FROM inventory_rules WHERE id = ?;", [
    sqlight.text(id),
  ])
}

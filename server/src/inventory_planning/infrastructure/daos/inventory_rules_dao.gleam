import gleam/int
import gleam/list
import gleam/string
import infrastructure/stores/sqlite_store

type RuleTuple =
  #(String, String, String)

type ProjectionTuple =
  #(String, String, String, Int, String)

pub fn upsert(id: String, location_name: String, expression: String) -> Nil {
  let sql =
    "INSERT INTO inventory_rules (id, location_name, expression) VALUES ("
    <> sqlite_store.quote(id)
    <> ", "
    <> sqlite_store.quote(location_name)
    <> ", "
    <> sqlite_store.quote(expression)
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  location_name = excluded.location_name,"
    <> "  expression = excluded.expression,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql)
}

pub fn list() -> List(RuleTuple) {
  let output =
    sqlite_store.query(
      "SELECT id, location_name, expression "
      <> "FROM inventory_rules "
      <> "ORDER BY location_name ASC, id ASC;",
    )

  output
  |> parse_rule_rows
}

pub fn delete(id: String) -> Nil {
  let sql =
    "DELETE FROM inventory_rules WHERE id = " <> sqlite_store.quote(id) <> ";"
  sqlite_store.exec(sql)
}

pub fn projection(sort_by: String, group_by: String) -> List(ProjectionTuple) {
  let group_expr = case group_by {
    "set_code" -> "s.set_code"
    _ -> "r.location_name"
  }

  let sort_expr = case sort_by {
    "set_code" -> "s.set_code"
    "quantity" -> "SUM(s.quantity)"
    _ -> "s.card_name"
  }

  let sql =
    "WITH latest_succeeded AS ("
    <> "  SELECT id FROM import_runs"
    <> "  WHERE status = 'succeeded'"
    <> "  ORDER BY updated_at DESC, created_at DESC"
    <> "  LIMIT 1"
    <> ") "
    <> "SELECT "
    <> "  r.location_name,"
    <> "  s.card_name,"
    <> "  s.set_code,"
    <> "  SUM(s.quantity),"
    <> group_expr
    <> " "
    <> "FROM collection_snapshot s "
    <> "JOIN latest_succeeded ls ON s.import_run_id = ls.id "
    <> "JOIN inventory_rules r ON r.expression = 'set_code=' || s.set_code "
    <> "GROUP BY r.location_name, s.card_name, s.set_code, "
    <> group_expr
    <> " "
    <> "ORDER BY "
    <> sort_expr
    <> " ASC, r.location_name ASC, s.card_name ASC;"

  sqlite_store.query(sql)
  |> parse_projection_rows
}

fn parse_rule_rows(output: String) -> List(RuleTuple) {
  output
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    case line == "" {
      True -> Error(Nil)
      False ->
        case string.split(line, "\t") {
          [id, location_name, expression] ->
            Ok(#(id, location_name, expression))
          _ -> Error(Nil)
        }
    }
  })
}

fn parse_projection_rows(output: String) -> List(ProjectionTuple) {
  output
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    case line == "" {
      True -> Error(Nil)
      False ->
        case string.split(line, "\t") {
          [location_name, card_name, set_code, quantity_raw, group_value] ->
            case int.parse(quantity_raw) {
              Ok(quantity) ->
                Ok(#(location_name, card_name, set_code, quantity, group_value))
              Error(_) -> Error(Nil)
            }

          _ -> Error(Nil)
        }
    }
  })
}

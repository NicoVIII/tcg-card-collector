import gleam/list
import gleam/option.{type Option}
import inventory_planning/infrastructure/daos/inventory_rules_dao.{type RuleRow}
import inventory_planning/infrastructure/daos/placed_cards_dao.{
  type PlacedCardRow,
}
import shared/infrastructure/stores/sqlite_store
import sqlight

/// Replaces whichever of rules/bulk/placed are present, atomically together
/// — Portability's restore (ADR 0019). `None` leaves that table untouched;
/// a present but empty `Some([])` clears it, same as any other
/// present-but-empty section. A full delete-then-insert, unlike `upsert`/
/// `increment`'s per-row merge: a restore states the whole table, the way
/// `collection_dao.replace_collection` already does for the collection.
pub fn replace(
  rules: Option(List(RuleRow)),
  bulk: Option(#(String, String)),
  placed: Option(List(PlacedCardRow)),
) -> Result(Nil, String) {
  let statements =
    list.flatten([
      option_statements(rules, rule_statements),
      option_statements(bulk, fn(spec) { [bulk_statement(spec)] }),
      option_statements(placed, placed_statements),
    ])

  case statements {
    [] -> Ok(Nil)
    _ -> sqlite_store.exec_all_atomically(statements)
  }
}

fn option_statements(
  section: Option(a),
  to_statements: fn(a) -> List(#(String, List(sqlight.Value))),
) -> List(#(String, List(sqlight.Value))) {
  case section {
    option.Some(value) -> to_statements(value)
    option.None -> []
  }
}

fn rule_statements(
  rows: List(RuleRow),
) -> List(#(String, List(sqlight.Value))) {
  [
    #("DELETE FROM inventory_rules;", []),
    ..list.map(rows, rule_insert_statement)
  ]
}

fn rule_insert_statement(row: RuleRow) -> #(String, List(sqlight.Value)) {
  #(
    "INSERT INTO inventory_rules (id, location_name, expression, position, selector, sort_keys) "
      <> "VALUES (?, ?, ?, ?, ?, ?);",
    [
      sqlight.text(row.id),
      sqlight.text(row.location_name),
      sqlight.text(row.expression),
      sqlight.int(row.position),
      sqlight.text(row.selector),
      sqlight.text(row.sort_keys),
    ],
  )
}

fn bulk_statement(spec: #(String, String)) -> #(String, List(sqlight.Value)) {
  let #(location_name, sort_keys) = spec
  #(
    "INSERT INTO inventory_bulk_spec (id, location_name, sort_keys, updated_at) "
      <> "VALUES (1, ?, ?, CURRENT_TIMESTAMP) "
      <> "ON CONFLICT(id) DO UPDATE SET "
      <> "  location_name = excluded.location_name,"
      <> "  sort_keys = excluded.sort_keys,"
      <> "  updated_at = CURRENT_TIMESTAMP;",
    [sqlight.text(location_name), sqlight.text(sort_keys)],
  )
}

fn placed_statements(
  rows: List(PlacedCardRow),
) -> List(#(String, List(sqlight.Value))) {
  [
    #("DELETE FROM placed_cards;", []),
    ..list.map(rows, placed_insert_statement)
  ]
}

fn placed_insert_statement(
  row: PlacedCardRow,
) -> #(String, List(sqlight.Value)) {
  #(
    "INSERT INTO placed_cards (set_code, collector_number, finish, language, location, quantity) "
      <> "VALUES (?, ?, ?, ?, ?, ?);",
    [
      sqlight.text(row.set_code),
      sqlight.text(row.collector_number),
      sqlight.text(row.finish),
      sqlight.text(row.language),
      sqlight.text(row.location),
      sqlight.int(row.quantity),
    ],
  )
}

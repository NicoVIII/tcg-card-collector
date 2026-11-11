import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/result
import inventory_planning/domain/managed_location.{type ManagedLocation}
import shared/domain/copy_key
import shared/infrastructure/stores/sqlite_store
import sqlight

pub type ManagedLocationRow {
  ManagedLocationRow(id: String, name: String, kind: String)
}

pub type MemberRow {
  MemberRow(
    managed_location_id: String,
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

fn location_row_decoder() -> decode.Decoder(ManagedLocationRow) {
  use id <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use kind <- decode.field(2, decode.string)
  decode.success(ManagedLocationRow(id:, name:, kind:))
}

fn member_row_decoder() -> decode.Decoder(MemberRow) {
  use managed_location_id <- decode.field(0, decode.string)
  use set_code <- decode.field(1, decode.string)
  use collector_number <- decode.field(2, decode.string)
  use finish <- decode.field(3, decode.string)
  use language <- decode.field(4, decode.string)
  use quantity <- decode.field(5, decode.int)
  decode.success(MemberRow(
    managed_location_id:,
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  ))
}

fn list_locations() -> Result(List(ManagedLocationRow), String) {
  sqlite_store.query(
    "SELECT id, name, kind FROM managed_locations ORDER BY name, id;",
    [],
    location_row_decoder(),
  )
}

pub fn list_members() -> Result(List(MemberRow), String) {
  sqlite_store.query(
    "SELECT managed_location_id, set_code, collector_number, finish, language, quantity "
      <> "FROM managed_location_members "
      <> "ORDER BY managed_location_id, set_code, collector_number, finish, language;",
    [],
    member_row_decoder(),
  )
}

/// Every managed location with its members, as the domain type. A row that
/// fails to parse (only reachable through manual DB surgery — the CHECKs and
/// the write-side parse keep it out otherwise) is skipped rather than
/// failing the whole read, the same precedent as the placed-ledger adapters.
pub fn load_all() -> Result(List(ManagedLocation), String) {
  use locations <- result.try(list_locations())
  use members <- result.map(list_members())
  list.filter_map(locations, fn(row) {
    use kind <- result.map(managed_location.kind_from_string(row.kind))
    managed_location.ManagedLocation(
      id: row.id,
      name: row.name,
      kind:,
      members: members_of(members, row.id),
    )
  })
}

fn members_of(
  members: List(MemberRow),
  id: String,
) -> dict.Dict(copy_key.CopyKey, Int) {
  members
  |> list.filter(fn(member) { member.managed_location_id == id })
  |> list.filter_map(fn(member) {
    copy_key.new(
      set_code: member.set_code,
      collector_number: member.collector_number,
      finish: member.finish,
      language: member.language,
    )
    |> result.map(fn(key) { #(key, member.quantity) })
    |> result.replace_error(Nil)
  })
  |> dict.from_list
}

pub fn insert(row: ManagedLocationRow) -> Result(Nil, String) {
  sqlite_store.exec(
    "INSERT INTO managed_locations (id, name, kind) VALUES (?, ?, ?);",
    [sqlight.text(row.id), sqlight.text(row.name), sqlight.text(row.kind)],
  )
}

pub fn rename(id: String, name: String) -> Result(Nil, String) {
  sqlite_store.exec("UPDATE managed_locations SET name = ? WHERE id = ?;", [
    sqlight.text(name),
    sqlight.text(id),
  ])
}

/// Removes the location, its members, its audit history, and every
/// placed-ledger row recorded at it, together — its copies re-enter placement
/// guidance at their cascade destination (ADR 0022). Spelled out rather than left to ON DELETE CASCADE:
/// the ledger's location column is polymorphic, and the app's connections
/// don't enable foreign keys.
pub fn delete(id: String) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically([
    #(
      "DELETE FROM placed_cards WHERE location_kind = 'managed' AND location = ?;",
      [sqlight.text(id)],
    ),
    #("DELETE FROM managed_location_members WHERE managed_location_id = ?;", [
      sqlight.text(id),
    ]),
    #(
      "DELETE FROM location_audits WHERE location_kind = 'managed' AND location = ?;",
      [sqlight.text(id)],
    ),
    #("DELETE FROM managed_locations WHERE id = ?;", [sqlight.text(id)]),
  ])
}

pub fn member_row(
  id: String,
  delta: managed_location.MemberDelta,
) -> MemberRow {
  MemberRow(
    managed_location_id: id,
    set_code: copy_key.set_code_string(delta.key),
    collector_number: copy_key.collector_number_string(delta.key),
    finish: copy_key.finish_string(delta.key),
    language: copy_key.language_string(delta.key),
    quantity: delta.quantity,
  )
}

fn member_params(row: MemberRow) -> List(sqlight.Value) {
  [
    sqlight.text(row.managed_location_id),
    sqlight.text(row.set_code),
    sqlight.text(row.collector_number),
    sqlight.text(row.finish),
    sqlight.text(row.language),
    sqlight.int(row.quantity),
  ]
}

fn increment_statement(row: MemberRow) -> #(String, List(sqlight.Value)) {
  #(
    "INSERT INTO managed_location_members "
      <> "(managed_location_id, set_code, collector_number, finish, language, quantity) "
      <> "VALUES (?, ?, ?, ?, ?, ?) "
      <> "ON CONFLICT(managed_location_id, set_code, collector_number, finish, language) "
      <> "DO UPDATE SET quantity = quantity + excluded.quantity;",
    member_params(row),
  )
}

/// Adds each row's quantity onto the matching member, inserting it when
/// absent, all in one transaction.
pub fn increment_members(rows: List(MemberRow)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically(list.map(rows, increment_statement))
}

// Same delete-or-update pair as placed_cards_dao.decrement: the CHECK
// (quantity > 0) forbids writing a non-positive row, and the two WHERE
// clauses are mutually exclusive.
fn decrement_statements(
  row: MemberRow,
) -> List(#(String, List(sqlight.Value))) {
  let where_key =
    " WHERE managed_location_id = ? AND set_code = ? AND collector_number = ? "
    <> "AND finish = ? AND language = ?"
  let key_params = [
    sqlight.text(row.managed_location_id),
    sqlight.text(row.set_code),
    sqlight.text(row.collector_number),
    sqlight.text(row.finish),
    sqlight.text(row.language),
  ]
  [
    #(
      "DELETE FROM managed_location_members"
        <> where_key
        <> " AND quantity <= ?;",
      list.append(key_params, [sqlight.int(row.quantity)]),
    ),
    #(
      "UPDATE managed_location_members SET quantity = quantity - ?"
        <> where_key
        <> " AND quantity > ?;",
      list.flatten([
        [sqlight.int(row.quantity)],
        key_params,
        [sqlight.int(row.quantity)],
      ]),
    ),
  ]
}

/// Subtracts each row's quantity from the matching member, pruning any
/// driven to zero, all in one transaction.
pub fn decrement_members(rows: List(MemberRow)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically(list.flat_map(rows, decrement_statements))
}

import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/result
import gleam/string
import shared/infrastructure/os_runtime
import sqlight

const default_db_file = "db/tcg-card-collector.db"

pub fn db_file() -> String {
  os_runtime.getenv_or("TCG_DB_FILE", default_db_file)
}

// Ports speak `Result(_, String)`; converting here keeps every DAO from
// repeating it.
fn message(error: sqlight.Error) -> String {
  error.message
}

/// Run a parameterized statement for its side effect (INSERT/UPDATE/DELETE).
pub fn exec(sql: String, params: List(sqlight.Value)) -> Result(Nil, String) {
  use conn <- sqlight.with_connection(db_file())
  sqlight.query(sql, on: conn, with: params, expecting: decode.success(Nil))
  |> result.map(fn(_) { Nil })
  |> result.map_error(message)
}

/// Run several parameterized statements in one transaction: either every
/// statement takes effect or none does. `exec` opens a fresh connection per
/// call, so multi-statement atomicity has to come through here.
pub fn exec_all_atomically(
  statements: List(#(String, List(sqlight.Value))),
) -> Result(Nil, String) {
  use conn <- sqlight.with_connection(db_file())
  run_atomically(conn, statements)
  |> result.map_error(message)
}

fn run_atomically(
  conn: sqlight.Connection,
  statements: List(#(String, List(sqlight.Value))),
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.exec("BEGIN;", conn))
  let outcome =
    list.try_each(statements, fn(statement) {
      let #(sql, params) = statement
      sqlight.query(sql, on: conn, with: params, expecting: decode.success(Nil))
      |> result.map(fn(_) { Nil })
    })
  case outcome {
    Ok(Nil) -> sqlight.exec("COMMIT;", conn)
    Error(error) -> {
      // nolint: discarded_result -- the caller needs the original error; a failed rollback cannot improve on it
      let _ = sqlight.exec("ROLLBACK;", conn)
      Error(error)
    }
  }
}

/// Run a parameterized SELECT and decode each row.
pub fn query(
  sql: String,
  params: List(sqlight.Value),
  decoder: Decoder(t),
) -> Result(List(t), String) {
  use conn <- sqlight.with_connection(db_file())
  sqlight.query(sql, on: conn, with: params, expecting: decoder)
  |> result.map_error(message)
}

/// `count` copies of `row` (e.g. "?" or "(?,?)"), comma-separated, for an
/// `IN (...)` list or a multi-row `VALUES`.
pub fn placeholders(count: Int, row: String) -> String {
  list.repeat(row, count)
  |> string.join(", ")
}

/// Runs `run` over `items` in chunks of `chunk_size` and concatenates the rows.
/// Chunking keeps each statement under SQLite's bound-parameter cap (default
/// 999); an empty input returns no rows without running SQL, where `IN ()`
/// would be a syntax error.
pub fn query_in_chunks(
  items: List(a),
  chunk_size: Int,
  run: fn(List(a)) -> Result(List(b), String),
) -> Result(List(b), String) {
  items
  |> list.sized_chunk(chunk_size)
  |> list.try_map(run)
  |> result.map(list.flatten)
}

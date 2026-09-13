import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/result
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

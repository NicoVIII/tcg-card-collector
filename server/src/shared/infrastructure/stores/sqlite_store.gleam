import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/result
import shared/infrastructure/os_runtime
import sqlight

const default_db_file = "db/tcg-card-collector.db"

pub fn db_file() -> String {
  os_runtime.getenv_or("TCG_DB_FILE", default_db_file)
}

/// Run a parameterized statement for its side effect (INSERT/UPDATE/DELETE).
pub fn exec(
  sql: String,
  params: List(sqlight.Value),
) -> Result(Nil, sqlight.Error) {
  use conn <- sqlight.with_connection(db_file())
  case
    sqlight.query(sql, on: conn, with: params, expecting: decode.success(Nil))
  {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

/// Run several parameterized statements in one transaction: either every
/// statement takes effect or none does. `exec` opens a fresh connection per
/// call, so multi-statement atomicity has to come through here.
pub fn exec_all_atomically(
  statements: List(#(String, List(sqlight.Value))),
) -> Result(Nil, sqlight.Error) {
  use conn <- sqlight.with_connection(db_file())
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
) -> Result(List(t), sqlight.Error) {
  use conn <- sqlight.with_connection(db_file())
  sqlight.query(sql, on: conn, with: params, expecting: decoder)
}

import gleam/dynamic/decode.{type Decoder}
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

/// Run a parameterized SELECT and decode each row.
pub fn query(
  sql: String,
  params: List(sqlight.Value),
  decoder: Decoder(t),
) -> Result(List(t), sqlight.Error) {
  use conn <- sqlight.with_connection(db_file())
  sqlight.query(sql, on: conn, with: params, expecting: decoder)
}

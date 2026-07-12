import gleam/bool
import gleam/string

// The source's stable identity for a card's rules text, shared across its
// printings. Opaque and non-empty; absence ("" at the source, e.g. reversible
// layouts) is modeled as Option(OracleId) at the use site, not as a sentinel.
pub opaque type OracleId {
  OracleId(value: String)
}

pub fn new(raw: String) -> Result(OracleId, Nil) {
  let trimmed = string.trim(raw)
  use <- bool.guard(trimmed == "", Error(Nil))

  Ok(OracleId(trimmed))
}

pub fn to_string(oracle_id: OracleId) -> String {
  oracle_id.value
}

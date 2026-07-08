import gleam/dict.{type Dict}

// A missing set is a legitimate absence (empty entry, handled by the domain's
// card-date fallback); a read *error* is a genuine failure and propagates
// rather than masquerading as "no dates known".
pub type GetSetReleaseDatesPort =
  fn(List(String)) -> Result(Dict(String, String), String)

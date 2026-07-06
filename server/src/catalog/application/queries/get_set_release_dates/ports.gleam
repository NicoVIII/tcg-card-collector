import gleam/dict.{type Dict}

// Infallible: absence and error both mean "no date known", which the domain
// handles via its card-date fallback; propagating errors here would add
// complexity without changing the outcome for any caller.
pub type GetSetReleaseDatesPort =
  fn(List(String)) -> Dict(String, String)

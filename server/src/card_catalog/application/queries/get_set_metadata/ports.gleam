import gleam/dict.{type Dict}
import gleam/option.{type Option}
import shared/domain/release_date.{type ReleaseDate}

// The catalog facts a set-family projection needs about one set: its release
// date (None when the source doesn't date the set) and the parent set it hangs
// off (None for a root set).
pub type SetMetadata {
  SetMetadata(released_at: Option(ReleaseDate), parent_set_code: Option(String))
}

// A set missing from the catalog is simply absent from the dict (handled by the
// domain's fallbacks); a read *error* is a genuine failure and propagates
// rather than masquerading as "no metadata known".
pub type GetSetMetadataPort =
  fn(List(String)) -> Result(Dict(String, SetMetadata), String)

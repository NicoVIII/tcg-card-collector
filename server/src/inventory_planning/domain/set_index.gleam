import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}

// The catalog facts set-family resolution needs about one set: its release date
// and the parent set it hangs off (None for a root set).
pub type SetMeta {
  SetMeta(released_at: String, parent_set_code: Option(String))
}

// Set metadata keyed by set code. Sets not present are simply absent; callers
// fall back (unknown release date "", own code as family root).
pub type SetIndex =
  Dict(String, SetMeta)

// The set's catalog release date, or "" when the set isn't in the index.
pub fn release_date(index: SetIndex, code: String) -> String {
  case dict.get(index, code) {
    Ok(meta) -> meta.released_at
    Error(_) -> ""
  }
}

// Bounds the parent walk; a corrupt parent chain (e.g. a↔b) terminates
// deterministically at the fuel limit instead of looping forever.
const max_depth = 10

fn family_root_loop(index: SetIndex, code: String, fuel: Int) -> String {
  case fuel <= 0 {
    True -> code
    False ->
      case dict.get(index, code) {
        Error(_) -> code
        Ok(meta) ->
          case meta.parent_set_code {
            None -> code
            Some(parent) -> family_root_loop(index, parent, fuel - 1)
          }
      }
  }
}

// The family root: walk parent links up to the topmost set with no parent. An
// unknown set or a root set resolves to its own code.
pub fn family_root(index: SetIndex, code: String) -> String {
  family_root_loop(index, code, max_depth)
}

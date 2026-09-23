// Shared wire-to-domain parsing for the name/set-code card filter, used by
// both bounded contexts (card_catalog, collection) across both doors (skir,
// http) — one place decides that a blank filter counts as absent.
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import shared/domain/set_code.{type SetCode}

pub fn parse_name(raw: Option(String)) -> Option(String) {
  case option.map(raw, string.trim) {
    Some("") | None -> None
    Some(trimmed) -> Some(trimmed)
  }
}

pub fn parse_set_code(raw: Option(String)) -> Option(SetCode) {
  case raw {
    None -> None
    Some(value) ->
      set_code.from_user_input(value)
      |> result.map(Some)
      |> result.unwrap(None)
  }
}

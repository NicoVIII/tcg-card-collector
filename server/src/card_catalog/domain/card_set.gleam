import gleam/option.{type Option, None, Some}
import gleam/string
import shared/domain/release_date.{type ReleaseDate}

pub type CardSet {
  CardSet(
    code: String,
    name: String,
    // None when the source doesn't date the set (documented nullable).
    released_at: Option(ReleaseDate),
    card_count: Int,
    // Scryfall's printed_size: the official set size (printed collector-number
    // denominator), excluding extras. None when Scryfall omits it.
    printed_size: Option(Int),
    icon_svg_uri: String,
    // The parent set this set belongs to (tokens, promos, art series, … hang off
    // their parent), canonicalized like `code`. None for root sets.
    parent_set_code: Option(String),
  )
}

// Trim/lowercase like `code`; a blank parent is no parent (Scryfall may send "").
fn canonical_parent(raw: Option(String)) -> Option(String) {
  case raw {
    None -> None
    Some(value) ->
      case string.lowercase(string.trim(value)) {
        "" -> None
        code -> Some(code)
      }
  }
}

pub fn from_raw(
  code raw_code: String,
  name raw_name: String,
  released_at raw_released_at: String,
  card_count card_count: Int,
  printed_size printed_size: Option(Int),
  icon_svg_uri icon_svg_uri: String,
  parent_set_code raw_parent: Option(String),
) -> Result(CardSet, String) {
  let code = string.lowercase(string.trim(raw_code))
  let name = string.trim(raw_name)
  let parent_set_code = canonical_parent(raw_parent)
  // An absent date is a modeled fact; a present-but-malformed one is a source
  // defect and rejects the set (ADR 0008).
  let released_at = case string.trim(raw_released_at) {
    "" -> Ok(None)
    raw ->
      case release_date.parse(raw) {
        Ok(date) -> Ok(Some(date))
        Error(_) -> Error("invalid released_at: " <> raw)
      }
  }
  case code, name, released_at {
    "", _, _ -> Error("empty set_code")
    _, "", _ -> Error("empty name")
    _, _, Error(reason) -> Error(reason)
    _, _, Ok(released_at) ->
      Ok(CardSet(
        code:,
        name:,
        released_at:,
        card_count:,
        printed_size:,
        icon_svg_uri:,
        parent_set_code:,
      ))
  }
}

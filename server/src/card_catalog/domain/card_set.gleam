import gleam/option.{type Option, None, Some}
import gleam/string

pub type CardSet {
  CardSet(
    code: String,
    name: String,
    released_at: String,
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
  released_at released_at: String,
  card_count card_count: Int,
  printed_size printed_size: Option(Int),
  icon_svg_uri icon_svg_uri: String,
  parent_set_code raw_parent: Option(String),
) -> Result(CardSet, String) {
  let code = string.lowercase(string.trim(raw_code))
  let name = string.trim(raw_name)
  let parent_set_code = canonical_parent(raw_parent)
  case code, name {
    "", _ -> Error("empty set_code")
    _, "" -> Error("empty name")
    _, _ ->
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

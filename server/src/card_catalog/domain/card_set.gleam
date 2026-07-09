import gleam/option.{type Option}
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
  )
}

pub fn from_raw(
  code raw_code: String,
  name raw_name: String,
  released_at released_at: String,
  card_count card_count: Int,
  printed_size printed_size: Option(Int),
  icon_svg_uri icon_svg_uri: String,
) -> Result(CardSet, String) {
  let code = string.lowercase(string.trim(raw_code))
  let name = string.trim(raw_name)
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
      ))
  }
}

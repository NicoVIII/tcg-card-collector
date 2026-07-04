import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import shared/domain/card_key.{type CardKey}

// Planning's value types, parsed from the opaque strings the catalog carries.
// The catalog owns the raw metadata; these types give planning the semantics it
// needs (a total order over rarity, a canonical color identity, a card type)
// without leaking planning rules back into the catalog.

// Total order: common < uncommon < special < bonus < rare < mythic. special and
// bonus sit *below* rare deliberately, so `rarity >= rare` excludes them; the
// escape hatch is `rarity in (...)`.
pub type Rarity {
  Common
  Uncommon
  Special
  Bonus
  Rare
  Mythic
}

pub fn parse_rarity(raw: String) -> Result(Rarity, Nil) {
  case string.lowercase(string.trim(raw)) {
    "common" -> Ok(Common)
    "uncommon" -> Ok(Uncommon)
    "special" -> Ok(Special)
    "bonus" -> Ok(Bonus)
    "rare" -> Ok(Rare)
    "mythic" -> Ok(Mythic)
    _ -> Error(Nil)
  }
}

pub fn rarity_to_string(rarity: Rarity) -> String {
  case rarity {
    Common -> "common"
    Uncommon -> "uncommon"
    Special -> "special"
    Bonus -> "bonus"
    Rare -> "rare"
    Mythic -> "mythic"
  }
}

pub fn rarity_rank(rarity: Rarity) -> Int {
  case rarity {
    Common -> 0
    Uncommon -> 1
    Special -> 2
    Bonus -> 3
    Rare -> 4
    Mythic -> 5
  }
}

pub fn rarity_at_least(rarity: Rarity, threshold: Rarity) -> Bool {
  rarity_rank(rarity) >= rarity_rank(threshold)
}

// The five WUBRG colors, kept in canonical order via their rank.
pub type Color {
  White
  Blue
  Black
  Red
  Green
}

fn color_rank(color: Color) -> Int {
  case color {
    White -> 0
    Blue -> 1
    Black -> 2
    Red -> 3
    Green -> 4
  }
}

fn color_letter(color: Color) -> String {
  case color {
    White -> "W"
    Blue -> "U"
    Black -> "B"
    Red -> "R"
    Green -> "G"
  }
}

fn parse_color_letter(letter: String) -> Result(Color, Nil) {
  case string.uppercase(letter) {
    "W" -> Ok(White)
    "U" -> Ok(Blue)
    "B" -> Ok(Black)
    "R" -> Ok(Red)
    "G" -> Ok(Green)
    _ -> Error(Nil)
  }
}

// Colors are held in canonical WUBRG order with no duplicates; the empty list is
// colorless. Opaque so equality is meaningful (WU == UW).
pub opaque type ColorIdentity {
  ColorIdentity(colors: List(Color))
}

fn canonical(colors: List(Color)) -> ColorIdentity {
  colors
  |> list.unique
  |> list.sort(fn(a, b) { int.compare(color_rank(a), color_rank(b)) })
  |> ColorIdentity
}

pub fn colorless() -> ColorIdentity {
  ColorIdentity([])
}

// Accepts the catalog's joined-letter form ("WU", "" for colorless) and the DSL
// form ("colorless"). Any letter order is accepted; the result is canonical.
pub fn parse_color_identity(raw: String) -> Result(ColorIdentity, Nil) {
  let trimmed = string.trim(raw)
  case string.lowercase(trimmed) {
    "" | "colorless" | "c" -> Ok(colorless())
    _ ->
      trimmed
      |> string.to_graphemes
      |> list.try_map(parse_color_letter)
      |> result.map(canonical)
  }
}

pub fn color_identity_is_colorless(identity: ColorIdentity) -> Bool {
  identity.colors == []
}

// Joined-letter form used in predicate DSL strings ("WU"); colorless is "".
pub fn color_identity_letters(identity: ColorIdentity) -> String {
  identity.colors |> list.map(color_letter) |> string.join("")
}

// DSL token that round-trips through parse_color_identity ("WU" / "colorless").
pub fn color_identity_token(identity: ColorIdentity) -> String {
  case color_identity_is_colorless(identity) {
    True -> "colorless"
    False -> color_identity_letters(identity)
  }
}

// Human-facing label for location templates ("WU" / "Colorless").
pub fn color_identity_label(identity: ColorIdentity) -> String {
  case color_identity_is_colorless(identity) {
    True -> "Colorless"
    False -> color_identity_letters(identity)
  }
}

// Sort key implementing display order WUBRG (mono) -> multicolor -> colorless.
// The digit string encodes color ranks in canonical order so mono-colors sort
// W, U, B, R, G rather than alphabetically.
pub fn color_identity_sort_key(identity: ColorIdentity) -> #(Int, String) {
  let digits =
    identity.colors
    |> list.map(fn(c) { int.to_string(color_rank(c)) })
    |> string.join("")
  let group = case list.length(identity.colors) {
    0 -> 2
    1 -> 0
    _ -> 1
  }
  #(group, digits)
}

// Priority list over the type line: the first type present wins.
pub type CardType {
  Land
  Creature
  Artifact
  Enchantment
  Planeswalker
  Battle
  Instant
  Sorcery
  Other
}

const type_priority = [
  #("land", Land),
  #("creature", Creature),
  #("artifact", Artifact),
  #("enchantment", Enchantment),
  #("planeswalker", Planeswalker),
  #("battle", Battle),
  #("instant", Instant),
  #("sorcery", Sorcery),
]

pub fn card_type_from_type_line(type_line: String) -> CardType {
  let lower = string.lowercase(type_line)
  type_priority
  |> list.find_map(fn(pair) {
    case string.contains(lower, pair.0) {
      True -> Ok(pair.1)
      False -> Error(Nil)
    }
  })
  |> result.unwrap(Other)
}

pub fn parse_card_type(raw: String) -> Result(CardType, Nil) {
  case string.lowercase(string.trim(raw)) {
    "land" -> Ok(Land)
    "creature" -> Ok(Creature)
    "artifact" -> Ok(Artifact)
    "enchantment" -> Ok(Enchantment)
    "planeswalker" -> Ok(Planeswalker)
    "battle" -> Ok(Battle)
    "instant" -> Ok(Instant)
    "sorcery" -> Ok(Sorcery)
    "other" -> Ok(Other)
    _ -> Error(Nil)
  }
}

pub fn card_type_to_string(card_type: CardType) -> String {
  case card_type {
    Land -> "land"
    Creature -> "creature"
    Artifact -> "artifact"
    Enchantment -> "enchantment"
    Planeswalker -> "planeswalker"
    Battle -> "battle"
    Instant -> "instant"
    Sorcery -> "sorcery"
    Other -> "other"
  }
}

pub fn card_type_rank(card_type: CardType) -> Int {
  case card_type {
    Land -> 0
    Creature -> 1
    Artifact -> 2
    Enchantment -> 3
    Planeswalker -> 4
    Battle -> 5
    Instant -> 6
    Sorcery -> 7
    Other -> 8
  }
}

// A collection row joined with whatever the catalog knew about it. oracle_id,
// rarity, color_identity, and card_type are optional because a collection row
// may reference a printing the catalog doesn't (yet) carry; such a card fails
// every attribute predicate and cascades through to bulk.
pub type PlannedCard {
  PlannedCard(
    key: CardKey,
    name: String,
    quantity: Int,
    released_at: String,
    oracle_id: Option(String),
    rarity: Option(Rarity),
    color_identity: Option(ColorIdentity),
    card_type: Option(CardType),
  )
}

// Canonical identity string for a printing (set_code/collector_number).
pub fn printing_key(card: PlannedCard) -> String {
  card_key.set_code_string(card.key)
  <> "/"
  <> card_key.collector_number_string(card.key)
}

import gleam/int
import gleam/list
import gleam/result
import gleam/string

// The five WUBRG colors. The canonical WUBRG order (via color_rank) is part of
// the representation — canonicalization sorts by it; display orderings built on
// top of it are context policy (ADR 0008).
pub type Color {
  White
  Blue
  Black
  Red
  Green
}

pub fn color_rank(color: Color) -> Int {
  case color {
    White -> 0
    Blue -> 1
    Black -> 2
    Red -> 3
    Green -> 4
  }
}

pub fn color_letter(color: Color) -> String {
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

// Accepts the joined-letter form the catalog source uses ("WU"; "" is
// colorless). Any letter order is accepted; the result is canonical. DSL
// spellings like "colorless" are consumer syntax, parsed in the consumer.
pub fn parse(raw: String) -> Result(ColorIdentity, Nil) {
  case string.trim(raw) {
    "" -> Ok(colorless())
    trimmed ->
      trimmed
      |> string.to_graphemes
      |> list.try_map(parse_color_letter)
      |> result.map(canonical)
  }
}

pub fn is_colorless(identity: ColorIdentity) -> Bool {
  identity.colors == []
}

// The colors in canonical WUBRG order.
pub fn colors(identity: ColorIdentity) -> List(Color) {
  identity.colors
}

// Joined-letter form ("WU"); colorless is "".
pub fn letters(identity: ColorIdentity) -> String {
  identity.colors |> list.map(color_letter) |> string.join("")
}

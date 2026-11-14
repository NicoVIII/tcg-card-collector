import gleam/option.{type Option, None, Some}

// Where a known official size came from; the precedence lives in `resolve`.
pub type SizeSource {
  ScryfallPrintedSize
  MtgjsonBaseSetSize
  TokenCardCount
}

// A set's official size: the collector-number denominator excluding extras.
pub type OfficialSize {
  Known(size: Int, source: SizeSource)
  Unknown
}

pub type SetKind {
  TokenSet
  OtherSet
}

pub fn set_kind_from_scryfall(set_type: String) -> SetKind {
  case set_type {
    "token" -> TokenSet
    _ -> OtherSet
  }
}

fn positive(size: Option(Int)) -> Option(Int) {
  case size {
    Some(n) if n > 0 -> Some(n)
    _ -> None
  }
}

// ADR 0025: Scryfall printed_size, then MTGJSON baseSetSize, then a token
// set's card_count. A size of 0 is upstream's spelling of "unknown".
pub fn resolve(
  printed_size printed_size: Option(Int),
  fallback_size fallback_size: Option(Int),
  kind kind: SetKind,
  card_count card_count: Int,
) -> OfficialSize {
  case positive(printed_size), positive(fallback_size), kind {
    Some(size), _, _ -> Known(size:, source: ScryfallPrintedSize)
    None, Some(size), _ -> Known(size:, source: MtgjsonBaseSetSize)
    None, None, TokenSet if card_count > 0 ->
      Known(size: card_count, source: TokenCardCount)
    None, None, _ -> Unknown
  }
}

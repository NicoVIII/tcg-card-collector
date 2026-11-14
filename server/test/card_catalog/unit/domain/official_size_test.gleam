import card_catalog/domain/official_size.{
  Known, MtgjsonBaseSetSize, OtherSet, ScryfallPrintedSize, TokenCardCount,
  TokenSet, Unknown,
}
import gleam/option.{None, Some}

pub fn printed_size_wins_over_fallback_test() {
  assert official_size.resolve(
      printed_size: Some(275),
      fallback_size: Some(286),
      kind: OtherSet,
      card_count: 400,
    )
    == Known(size: 275, source: ScryfallPrintedSize)
}

pub fn fallback_applies_without_printed_size_test() {
  assert official_size.resolve(
      printed_size: None,
      fallback_size: Some(269),
      kind: OtherSet,
      card_count: 397,
    )
    == Known(size: 269, source: MtgjsonBaseSetSize)
}

pub fn token_set_without_sizes_uses_card_count_test() {
  assert official_size.resolve(
      printed_size: None,
      fallback_size: None,
      kind: TokenSet,
      card_count: 9,
    )
    == Known(size: 9, source: TokenCardCount)
}

pub fn card_count_is_not_a_size_for_other_sets_test() {
  assert official_size.resolve(
      printed_size: None,
      fallback_size: None,
      kind: OtherSet,
      card_count: 312,
    )
    == Unknown
}

// MTGJSON reports 0 for Arena-only sets; an empty token set has no size either.
pub fn zero_is_unknown_test() {
  assert official_size.resolve(
      printed_size: Some(0),
      fallback_size: Some(0),
      kind: OtherSet,
      card_count: 0,
    )
    == Unknown
  assert official_size.resolve(
      printed_size: None,
      fallback_size: Some(0),
      kind: TokenSet,
      card_count: 0,
    )
    == Unknown
}

import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type TargetSetsPort =
  fn() -> Result(List(String), String)

pub type SetCardKeysPort =
  fn(List(String)) -> Result(Dict(String, List(String)), String)

// Per-set official size (Scryfall printed_size). None when the set has no
// official size, in which case completion is reported without a denominator.
pub type PrintedSizesPort =
  fn(List(String)) -> Result(Dict(String, Option(Int)), String)

pub type OwnedCard {
  OwnedCard(set_code: String, collector_number: String)
}

pub type OwnedCardsPort =
  fn() -> Result(List(OwnedCard), String)

pub type SetCompletionReadModel {
  SetCompletionReadModel(set_code: String, owned: Int, total: Option(Int))
}

pub type SetCompletionPorts {
  SetCompletionPorts(
    target_sets: TargetSetsPort,
    set_card_keys: SetCardKeysPort,
    printed_sizes: PrintedSizesPort,
    owned_cards: OwnedCardsPort,
  )
}

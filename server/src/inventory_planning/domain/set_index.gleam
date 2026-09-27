import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/domain/card_attributes.{type PlannedCard}
import shared/domain/card_key
import shared/domain/release_date.{type ReleaseDate}

// The catalog facts set-family resolution needs about one set: its release date
// (None when the catalog doesn't date it) and the parent set it hangs off
// (None for a root set).
pub type SetMeta {
  SetMeta(released_at: Option(ReleaseDate), parent_set_code: Option(String))
}

// Set metadata keyed by set code. Sets not present are simply absent; callers
// fall back (unknown release date None, own code as family root).
pub type SetIndex =
  Dict(String, SetMeta)

// The set's catalog release date, or None when the set isn't in the index or
// isn't dated.
pub fn release_date(index: SetIndex, code: String) -> Option(ReleaseDate) {
  case dict.get(index, code) {
    Ok(meta) -> meta.released_at
    Error(_) -> None
  }
}

// A set's effective release date: the catalog entry for `code`, else the
// earliest of the given card-level dates (card-level released_at can vary
// within a set — promos, Secret Lair drops, The List — so this is where
// bucket_set_date and stamp_set_release below share their one fallback
// policy), else None (sorts first, same posture as released_at's unknowns).
pub fn release_date_or_earliest(
  index: SetIndex,
  code: String,
  card_dates: List(Option(ReleaseDate)),
) -> Option(ReleaseDate) {
  case release_date(index, code) {
    Some(date) -> Some(date)
    None ->
      card_dates
      |> list.filter_map(option.to_result(_, Nil))
      |> list.sort(release_date.compare)
      |> list.first
      |> option.from_result
  }
}

// Stamps every card with its set's effective release date (#145), resolved
// once per set so a set with card-level date variance never splits under
// set_released_at. Order of `cards` is preserved.
pub fn stamp_set_release(
  index: SetIndex,
  cards: List(PlannedCard),
) -> List(PlannedCard) {
  let dates_by_set = resolved_dates_by_set(index, cards)
  list.map(cards, fn(card) {
    let code = card_key.set_code_string(card.key)
    let date = dict.get(dates_by_set, code) |> result.unwrap(None)
    card_attributes.PlannedCard(..card, set_released_at: date)
  })
}

fn resolved_dates_by_set(
  index: SetIndex,
  cards: List(PlannedCard),
) -> Dict(String, Option(ReleaseDate)) {
  let card_dates_by_set =
    list.fold(cards, dict.new(), fn(acc, card) {
      let code = card_key.set_code_string(card.key)
      dict.upsert(acc, code, fn(existing) {
        [card.released_at, ..option.unwrap(existing, [])]
      })
    })
  dict.map_values(card_dates_by_set, fn(code, card_dates) {
    release_date_or_earliest(index, code, card_dates)
  })
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

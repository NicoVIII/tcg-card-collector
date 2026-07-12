import collection/application/queries/list_cards/ports
import gleam/list
import gleam/order
import gleam/result
import shared/domain/card_key
import shared/domain/collector_number
import shared/domain/set_code

pub type ListCollectionCardsQuery {
  ListCollectionCardsQuery(offset: Int, limit: Int)
}

pub fn execute(
  query: ListCollectionCardsQuery,
  port: ports.ListCollectionCardsPort,
) -> Result(ports.CollectionCardPage, String) {
  use unsorted <- result.try(port.list_cards())
  let all_cards = list.sort(unsorted, by: compare_canonical)
  let total = list.length(all_cards)
  let paged_cards = paginate_cards(all_cards, query.offset, query.limit)
  Ok(ports.CollectionCardPage(cards: paged_cards, total: total))
}

// Physical filing order: set code, then collector number compared numerically
// so "grn 2" precedes "grn 10". The store can't express the numeric-aware order
// on a TEXT column, so the grid's order is decided here.
fn compare_canonical(
  a: ports.CollectionCardReadModel,
  b: ports.CollectionCardReadModel,
) -> order.Order {
  order.break_tie(
    set_code.compare(card_key.set_code(a.key), card_key.set_code(b.key)),
    collector_number.compare(
      card_key.collector_number(a.key),
      card_key.collector_number(b.key),
    ),
  )
}

fn paginate_cards(
  cards: List(ports.CollectionCardReadModel),
  offset: Int,
  limit: Int,
) -> List(ports.CollectionCardReadModel) {
  let normalized_offset = clamp_non_negative(offset)
  let normalized_limit = clamp_non_negative(limit)

  cards
  |> list.drop(normalized_offset)
  |> fn(remaining) {
    case normalized_limit {
      0 -> remaining
      _ -> list.take(remaining, normalized_limit)
    }
  }
}

fn clamp_non_negative(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

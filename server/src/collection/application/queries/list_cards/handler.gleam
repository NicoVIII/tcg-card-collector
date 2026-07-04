import collection/application/queries/list_cards/ports
import gleam/list
import gleam/result

pub type ListCollectionCardsQuery {
  ListCollectionCardsQuery(offset: Int, limit: Int)
}

pub fn execute(
  query: ListCollectionCardsQuery,
  port: ports.ListCollectionCardsPort,
) -> Result(ports.CollectionCardPage, String) {
  use all_cards <- result.try(port.list_cards())
  let total = list.length(all_cards)
  let paged_cards = paginate_cards(all_cards, query.offset, query.limit)
  Ok(ports.CollectionCardPage(cards: paged_cards, total: total))
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

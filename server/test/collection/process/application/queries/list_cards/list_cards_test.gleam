import collection/application/queries/list_cards/handler
import collection/application/queries/list_cards/ports

fn build_port(
  cards: List(ports.CollectionCardReadModel),
) -> ports.ListCollectionCardsPort {
  ports.ListCollectionCardsPort(list_cards: fn() { Ok(cards) })
}

fn card(
  set_code: String,
  collector_number: String,
) -> ports.CollectionCardReadModel {
  ports.CollectionCardReadModel(
    set_code: set_code,
    collector_number: collector_number,
    quantity: 1,
  )
}

// The store returns rows unordered; the grid's physical filing order is the
// handler's job — set code, then collector number compared numerically so
// "grn 2" precedes "grn 10" rather than sorting lexicographically after it.
pub fn orders_by_set_then_numeric_collector_number_test() {
  let port =
    build_port([
      card("grn", "10"),
      card("lea", "2"),
      card("grn", "2"),
      card("lea", "1"),
    ])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 0, limit: 0), port)

  assert page.cards
    == [card("grn", "2"), card("grn", "10"), card("lea", "1"), card("lea", "2")]
}

pub fn pages_within_bounds_and_reports_total_test() {
  let port = build_port([card("lea", "1"), card("lea", "2"), card("lea", "3")])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 1, limit: 1), port)

  assert page.cards == [card("lea", "2")]
  assert page.total == 3
}

pub fn limit_zero_returns_all_remaining_after_offset_test() {
  let port = build_port([card("lea", "1"), card("lea", "2"), card("lea", "3")])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 1, limit: 0), port)

  assert page.cards == [card("lea", "2"), card("lea", "3")]
  assert page.total == 3
}

pub fn negative_offset_and_limit_are_clamped_to_zero_test() {
  let port = build_port([card("lea", "1"), card("lea", "2")])

  let assert Ok(page) =
    handler.execute(
      handler.ListCollectionCardsQuery(offset: -5, limit: -5),
      port,
    )

  assert page.cards == [card("lea", "1"), card("lea", "2")]
  assert page.total == 2
}

pub fn offset_past_the_end_returns_an_empty_page_test() {
  let port = build_port([card("lea", "1")])

  let assert Ok(page) =
    handler.execute(
      handler.ListCollectionCardsQuery(offset: 5, limit: 10),
      port,
    )

  assert page.cards == []
  assert page.total == 1
}

pub fn list_cards_failure_propagates_as_error_test() {
  let port =
    ports.ListCollectionCardsPort(list_cards: fn() { Error("db unavailable") })

  let result =
    handler.execute(
      handler.ListCollectionCardsQuery(offset: 0, limit: 10),
      port,
    )

  assert result == Error("db unavailable")
}

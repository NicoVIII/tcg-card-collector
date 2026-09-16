import collection/application/queries/list_cards/handler
import collection/application/queries/list_cards/ports
import shared/domain/card_key
import shared/domain/copy_key

fn build_port(
  rows: List(ports.CollectionCopyReadModel),
) -> ports.ListCollectionCardsPort {
  ports.ListCollectionCardsPort(list_cards: fn() { Ok(rows) })
}

fn copy_row(
  set_code set_code: String,
  collector_number collector_number: String,
  finish finish: String,
  language language: String,
  quantity quantity: Int,
) -> ports.CollectionCopyReadModel {
  let assert Ok(key) =
    copy_key.new(set_code:, collector_number:, finish:, language:)
  ports.CollectionCopyReadModel(key:, quantity:)
}

fn nonfoil_en(
  set_code: String,
  collector_number: String,
  quantity: Int,
) -> ports.CollectionCopyReadModel {
  copy_row(
    set_code:,
    collector_number:,
    finish: "nonfoil",
    language: "en",
    quantity:,
  )
}

fn owned_copy(
  finish: String,
  language: String,
  quantity: Int,
) -> ports.OwnedCopy {
  ports.OwnedCopy(finish:, language:, quantity:)
}

fn printing(
  set_code: String,
  collector_number: String,
  copies: List(ports.OwnedCopy),
) -> ports.OwnedPrinting {
  let assert Ok(key) = card_key.new(set_code:, collector_number:)
  ports.OwnedPrinting(key:, copies:)
}

// The store returns rows unordered; the grid's physical filing order is the
// handler's job — set code, then collector number compared numerically so
// "grn 2" precedes "grn 10" rather than sorting lexicographically after it.
pub fn orders_by_set_then_numeric_collector_number_test() {
  let port =
    build_port([
      nonfoil_en("grn", "10", 1),
      nonfoil_en("lea", "2", 1),
      nonfoil_en("grn", "2", 1),
      nonfoil_en("lea", "1", 1),
    ])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 0, limit: 0), port)

  assert page.printings
    == [
      printing("grn", "2", [owned_copy("nonfoil", "en", 1)]),
      printing("grn", "10", [owned_copy("nonfoil", "en", 1)]),
      printing("lea", "1", [owned_copy("nonfoil", "en", 1)]),
      printing("lea", "2", [owned_copy("nonfoil", "en", 1)]),
    ]
}

// Copies of the same printing group into one entry, badge order: finish
// (nonfoil, foil, etched), then language alphabetically.
pub fn groups_copies_of_the_same_printing_test() {
  let port =
    build_port([
      copy_row(
        set_code: "m19",
        collector_number: "85",
        finish: "foil",
        language: "de",
        quantity: 1,
      ),
      copy_row(
        set_code: "m19",
        collector_number: "85",
        finish: "nonfoil",
        language: "en",
        quantity: 2,
      ),
      copy_row(
        set_code: "m19",
        collector_number: "85",
        finish: "nonfoil",
        language: "de",
        quantity: 1,
      ),
    ])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 0, limit: 0), port)

  assert page.printings
    == [
      printing("m19", "85", [
        owned_copy("nonfoil", "de", 1),
        owned_copy("nonfoil", "en", 2),
        owned_copy("foil", "de", 1),
      ]),
    ]
  assert page.total == 1
}

pub fn pages_within_bounds_and_reports_total_test() {
  let port =
    build_port([
      nonfoil_en("lea", "1", 1),
      nonfoil_en("lea", "2", 1),
      nonfoil_en("lea", "3", 1),
    ])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 1, limit: 1), port)

  assert page.printings
    == [printing("lea", "2", [owned_copy("nonfoil", "en", 1)])]
  assert page.total == 3
}

pub fn limit_zero_returns_all_remaining_after_offset_test() {
  let port =
    build_port([
      nonfoil_en("lea", "1", 1),
      nonfoil_en("lea", "2", 1),
      nonfoil_en("lea", "3", 1),
    ])

  let assert Ok(page) =
    handler.execute(handler.ListCollectionCardsQuery(offset: 1, limit: 0), port)

  assert page.printings
    == [
      printing("lea", "2", [owned_copy("nonfoil", "en", 1)]),
      printing("lea", "3", [owned_copy("nonfoil", "en", 1)]),
    ]
  assert page.total == 3
}

pub fn negative_offset_and_limit_are_clamped_to_zero_test() {
  let port = build_port([nonfoil_en("lea", "1", 1), nonfoil_en("lea", "2", 1)])

  let assert Ok(page) =
    handler.execute(
      handler.ListCollectionCardsQuery(offset: -5, limit: -5),
      port,
    )

  assert page.printings
    == [
      printing("lea", "1", [owned_copy("nonfoil", "en", 1)]),
      printing("lea", "2", [owned_copy("nonfoil", "en", 1)]),
    ]
  assert page.total == 2
}

pub fn offset_past_the_end_returns_an_empty_page_test() {
  let port = build_port([nonfoil_en("lea", "1", 1)])

  let assert Ok(page) =
    handler.execute(
      handler.ListCollectionCardsQuery(offset: 5, limit: 10),
      port,
    )

  assert page.printings == []
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

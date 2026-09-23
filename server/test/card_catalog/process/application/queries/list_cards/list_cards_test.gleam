import card_catalog/application/queries/list_cards/handler.{
  ListCatalogCardsQuery,
} as list_cards_handler
import card_catalog/application/queries/list_cards/ports.{
  type CatalogCardKeyReadModel, type ListCatalogCardsPort, CatalogCardFilter,
  CatalogCardKeyReadModel, ListCatalogCardsPort,
}
import gleam/option.{None, Some}
import shared/domain/set_code

fn build_port(rows: List(CatalogCardKeyReadModel)) -> ListCatalogCardsPort {
  ListCatalogCardsPort(list_cards: fn(_filter) { Ok(rows) })
}

pub fn execute_returns_the_ports_rows_unchanged_test() {
  let rows = [
    CatalogCardKeyReadModel(set_code: "lea", collector_number: "1"),
    CatalogCardKeyReadModel(set_code: "lea", collector_number: "2"),
  ]

  let result =
    list_cards_handler.execute(
      ListCatalogCardsQuery(filter: CatalogCardFilter(None, None)),
      build_port(rows),
    )

  assert result == Ok(rows)
}

pub fn execute_propagates_a_port_error_test() {
  let port = ListCatalogCardsPort(list_cards: fn(_filter) { Error("boom") })

  let result =
    list_cards_handler.execute(
      ListCatalogCardsQuery(filter: CatalogCardFilter(None, None)),
      port,
    )

  assert result == Error("boom")
}

pub fn execute_passes_the_name_filter_through_to_the_port_test() {
  let seen_filter = CatalogCardFilter(name: Some("bolt"), set_code: None)
  let port =
    ListCatalogCardsPort(list_cards: fn(filter) {
      assert filter == seen_filter
      Ok([])
    })

  let result =
    list_cards_handler.execute(ListCatalogCardsQuery(filter: seen_filter), port)

  assert result == Ok([])
}

pub fn execute_passes_the_set_code_filter_through_to_the_port_test() {
  let assert Ok(lea) = set_code.new("lea")
  let seen_filter = CatalogCardFilter(name: None, set_code: Some(lea))
  let port =
    ListCatalogCardsPort(list_cards: fn(filter) {
      assert filter == seen_filter
      Ok([])
    })

  let result =
    list_cards_handler.execute(ListCatalogCardsQuery(filter: seen_filter), port)

  assert result == Ok([])
}

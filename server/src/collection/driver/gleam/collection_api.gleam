import collection/application/queries/list_cards/handler as list_cards_handler
import collection/application/queries/list_cards/ports as list_cards_ports

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import collection/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter
import gleam/result

pub fn list_cards() -> Result(
  List(list_cards_ports.CollectionCardReadModel),
  String,
) {
  use page <- result.try(list_cards_handler.execute(
    list_cards_handler.ListCollectionCardsQuery(offset: 0, limit: 0),
    list_cards_adapter.new(),
  ))
  Ok(page.cards)
}

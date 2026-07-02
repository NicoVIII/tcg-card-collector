import collection/application/queries/list_cards/handler as list_cards_handler
import collection/application/queries/list_cards/ports as list_cards_ports

// nolint: depends_only_on -- glinter_arch (vendored submodule) doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a submodule change
import collection/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter

pub fn list_cards() -> List(list_cards_ports.CollectionCardReadModel) {
  list_cards_handler.execute(
    list_cards_handler.ListCollectionCardsQuery,
    list_cards_adapter.new(),
  )
}

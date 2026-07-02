import catalog/application/queries/get_cards/handler as get_cards_handler
import catalog/application/queries/get_cards/ports as get_cards_ports

// nolint: depends_only_on -- glinter_arch (vendored submodule) doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a submodule change
import catalog/infrastructure/adapters/queries/get_cards/adapter as get_cards_adapter

pub fn get_cards(
  keys: List(#(String, String)),
) -> List(get_cards_ports.CardReadModel) {
  get_cards_handler.execute(
    get_cards_handler.GetCatalogCardsQuery(keys:),
    get_cards_adapter.new(),
  )
}

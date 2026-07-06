import catalog/application/queries/get_cards/handler as get_cards_handler
import catalog/application/queries/get_cards/ports as get_cards_ports
import catalog/application/queries/get_set_release_dates/handler as get_set_release_dates_handler
import catalog/application/queries/list_set_card_keys/handler as list_set_card_keys_handler
import gleam/dict.{type Dict}

// nolint: depends_only_on -- glinter_arch (vendored submodule) doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a submodule change
import catalog/infrastructure/adapters/queries/get_cards/adapter as get_cards_adapter

// nolint: depends_only_on -- glinter_arch (vendored submodule) doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a submodule change
import catalog/infrastructure/adapters/queries/get_set_release_dates/adapter as get_set_release_dates_adapter

// nolint: depends_only_on -- glinter_arch (vendored submodule) doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a submodule change
import catalog/infrastructure/adapters/queries/list_set_card_keys/adapter as list_set_card_keys_adapter

pub fn get_cards(
  keys: List(#(String, String)),
) -> List(get_cards_ports.CardReadModel) {
  get_cards_handler.execute(
    get_cards_handler.GetCatalogCardsQuery(keys:),
    get_cards_adapter.new(),
  )
}

pub fn get_set_release_dates(set_codes: List(String)) -> Dict(String, String) {
  get_set_release_dates_handler.execute(
    get_set_release_dates_handler.GetSetReleaseDatesQuery(set_codes:),
    get_set_release_dates_adapter.new(),
  )
}

pub fn list_set_card_keys(
  set_codes: List(String),
) -> Dict(String, List(String)) {
  list_set_card_keys_handler.execute(
    list_set_card_keys_handler.ListSetCardKeysQuery(set_codes:),
    list_set_card_keys_adapter.new(),
  )
}

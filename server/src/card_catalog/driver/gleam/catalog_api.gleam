import card_catalog/application/queries/get_cards/handler as get_cards_handler
import card_catalog/application/queries/get_cards/ports as get_cards_ports
import card_catalog/application/queries/get_set_metadata/handler as get_set_metadata_handler
import card_catalog/application/queries/get_set_metadata/ports as get_set_metadata_ports
import card_catalog/application/queries/get_set_printed_sizes/handler as get_set_printed_sizes_handler
import card_catalog/application/queries/list_set_card_keys/handler as list_set_card_keys_handler
import gleam/dict.{type Dict}
import gleam/option.{type Option}

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import card_catalog/infrastructure/adapters/queries/get_cards/adapter as get_cards_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import card_catalog/infrastructure/adapters/queries/get_set_metadata/adapter as get_set_metadata_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import card_catalog/infrastructure/adapters/queries/get_set_printed_sizes/adapter as get_set_printed_sizes_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import card_catalog/infrastructure/adapters/queries/list_set_card_keys/adapter as list_set_card_keys_adapter

pub fn get_cards(
  keys: List(#(String, String)),
) -> Result(List(get_cards_ports.CardReadModel), String) {
  get_cards_handler.execute(
    get_cards_handler.GetCatalogCardsQuery(keys:),
    get_cards_adapter.new(),
  )
}

pub fn get_set_metadata(
  set_codes: List(String),
) -> Result(Dict(String, get_set_metadata_ports.SetMetadata), String) {
  get_set_metadata_handler.execute(
    get_set_metadata_handler.GetSetMetadataQuery(set_codes:),
    get_set_metadata_adapter.new(),
  )
}

pub fn list_set_card_keys(
  set_codes: List(String),
) -> Result(Dict(String, List(String)), String) {
  list_set_card_keys_handler.execute(
    list_set_card_keys_handler.ListSetCardKeysQuery(set_codes:),
    list_set_card_keys_adapter.new(),
  )
}

pub fn get_set_printed_sizes(
  set_codes: List(String),
) -> Result(Dict(String, Option(Int)), String) {
  get_set_printed_sizes_handler.execute(
    get_set_printed_sizes_handler.GetSetPrintedSizesQuery(set_codes:),
    get_set_printed_sizes_adapter.new(),
  )
}

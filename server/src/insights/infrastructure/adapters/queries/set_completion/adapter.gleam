import card_catalog/driver/gleam/catalog_api
import collection/driver/gleam/collection_api
import gleam/list
import gleam/result
import insights/application/queries/set_completion/ports
import insights/infrastructure/daos/insights_dao
import shared/domain/card_key

pub fn new() -> ports.SetCompletionPorts {
  ports.SetCompletionPorts(
    target_sets: target_sets_adapter(),
    set_card_keys: set_card_keys_adapter(),
    printed_sizes: printed_sizes_adapter(),
    owned_cards: owned_cards_adapter(),
  )
}

fn target_sets_adapter() -> ports.TargetSetsPort {
  fn() { insights_dao.list() }
}

fn set_card_keys_adapter() -> ports.SetCardKeysPort {
  fn(set_codes) { catalog_api.list_set_card_keys(set_codes) }
}

fn printed_sizes_adapter() -> ports.PrintedSizesPort {
  fn(set_codes) { catalog_api.get_set_printed_sizes(set_codes) }
}

fn owned_cards_adapter() -> ports.OwnedCardsPort {
  fn() {
    use cards <- result.try(collection_api.list_cards())
    Ok(
      list.map(cards, fn(card) {
        ports.OwnedCard(
          set_code: card_key.set_code_string(card.key),
          collector_number: card_key.collector_number_string(card.key),
        )
      }),
    )
  }
}

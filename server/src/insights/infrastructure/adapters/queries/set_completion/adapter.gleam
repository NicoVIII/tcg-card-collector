import catalog/driver/gleam/catalog_api
import collection/driver/gleam/collection_api
import gleam/list
import insights/application/queries/set_completion/ports
import insights/infrastructure/daos/insights_dao

pub fn new() -> ports.SetCompletionPorts {
  ports.SetCompletionPorts(
    target_sets: target_sets_adapter(),
    set_card_keys: set_card_keys_adapter(),
    owned_cards: owned_cards_adapter(),
  )
}

fn target_sets_adapter() -> ports.TargetSetsPort {
  fn() { insights_dao.list() }
}

fn set_card_keys_adapter() -> ports.SetCardKeysPort {
  fn(set_codes) { catalog_api.list_set_card_keys(set_codes) }
}

fn owned_cards_adapter() -> ports.OwnedCardsPort {
  fn() {
    collection_api.list_cards()
    |> list.map(fn(card) {
      ports.OwnedCard(
        set_code: card.set_code,
        collector_number: card.collector_number,
      )
    })
  }
}

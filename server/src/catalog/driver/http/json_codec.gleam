import catalog/application/queries/list_cards/ports as list_cards_ports
import gleam/json

pub type CatalogRefreshLaunch {
  RefreshStarted
  RefreshAlreadyRunning
}

pub fn encode_refresh_launch(launch: CatalogRefreshLaunch) -> String {
  let message = case launch {
    RefreshStarted -> "catalog refresh started"
    RefreshAlreadyRunning -> "catalog refresh already running"
  }
  json.object([#("ok", json.string(message))])
  |> json.to_string
}

pub fn encode_catalog_cards(
  cards: List(list_cards_ports.CatalogCardKeyReadModel),
) -> String {
  json.array(cards, of: encode_catalog_card_key)
  |> json.to_string
}

fn encode_catalog_card_key(
  key: list_cards_ports.CatalogCardKeyReadModel,
) -> json.Json {
  json.object([
    #("set_code", json.string(key.set_code)),
    #("collector_number", json.string(key.collector_number)),
  ])
}

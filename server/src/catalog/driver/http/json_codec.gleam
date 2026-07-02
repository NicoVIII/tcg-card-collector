import catalog/application/queries/list_cards/ports as list_cards_ports
import catalog/application/queries/refresh_status/ports as refresh_status_ports
import catalog/driver/refresh_launcher.{RefreshAlreadyRunning, RefreshStarted}
import gleam/json

pub fn encode_refresh_launch(
  launch: refresh_launcher.RefreshLaunchOutcome,
) -> String {
  let message = case launch {
    RefreshStarted -> "catalog refresh started"
    RefreshAlreadyRunning -> "catalog refresh already running"
  }
  json.object([#("ok", json.string(message))])
  |> json.to_string
}

pub fn encode_refresh_status(
  status: refresh_status_ports.RefreshStatusReadModel,
) -> String {
  json.object([
    #("status", json.string(status.status)),
    #("last_probe_at", json.string(status.last_probe_at)),
    #("last_upstream_updated_at", json.string(status.last_upstream_updated_at)),
    #("error_message", json.string(status.error_message)),
  ])
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

import catalog/application/queries/get_cards/ports as get_cards_ports
import catalog/application/queries/list_cards/ports as list_cards_ports
import catalog/application/queries/refresh_status/ports as refresh_status_ports
import catalog/driver/refresh_launcher.{RefreshAlreadyRunning, RefreshStarted}
import gleam/dynamic/decode
import gleam/json
import gleam/result

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

pub type GetCardsBody {
  GetCardsBody(keys: List(#(String, String)))
}

pub fn decode_get_cards_body(
  json_string: String,
) -> Result(GetCardsBody, String) {
  let key_decoder = {
    use set_code <- decode.field("set_code", decode.string)
    use collector_number <- decode.field("collector_number", decode.string)
    decode.success(#(set_code, collector_number))
  }
  let decoder = {
    use keys <- decode.field("keys", decode.list(key_decoder))
    decode.success(GetCardsBody(keys:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub fn encode_catalog_card_details(
  cards: List(get_cards_ports.CardReadModel),
) -> String {
  json.array(cards, of: encode_catalog_card_detail)
  |> json.to_string
}

fn encode_catalog_card_detail(
  card: get_cards_ports.CardReadModel,
) -> json.Json {
  json.object([
    #("set_code", json.string(card.set_code)),
    #("collector_number", json.string(card.collector_number)),
    #("name", json.string(card.name)),
    #("image_uri", json.string(card.image_uri)),
    #("rarity", json.string(card.rarity)),
    #("oracle_id", json.string(card.oracle_id)),
    #("color_identity", json.string(card.color_identity)),
    #("type_line", json.string(card.type_line)),
    #("released_at", json.string(card.released_at)),
  ])
}

import catalog/application/queries/list_cards/ports as list_cards_ports
import gleam/json

pub fn encode_catalog_cards(
  cards: List(list_cards_ports.CatalogCardReadModel),
) -> String {
  json.array(cards, of: encode_catalog_card)
  |> json.to_string
}

fn encode_catalog_card(
  card: list_cards_ports.CatalogCardReadModel,
) -> json.Json {
  json.object([
    #("id", json.string(card.id)),
    #("name", json.string(card.name)),
    #("set_code", json.string(card.set_code)),
  ])
}

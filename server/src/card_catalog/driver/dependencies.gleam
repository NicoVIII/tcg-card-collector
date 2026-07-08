import card_catalog/application/commands/refresh/ports as refresh_ports
import card_catalog/application/queries/get_cards/ports as get_cards_ports
import card_catalog/application/queries/list_cards/ports as list_cards_ports
import card_catalog/application/queries/refresh_status/ports as refresh_status_ports
import gleam/erlang/process

pub type Dependencies {
  Dependencies(
    refresh_catalog_ports: refresh_ports.RefreshCatalogPorts,
    list_catalog_cards_port: list_cards_ports.ListCatalogCardsPort,
    get_catalog_cards_port: get_cards_ports.GetCatalogCardsPort,
    get_refresh_status_port: refresh_status_ports.GetCatalogRefreshStatusPort,
    refresh_worker_name: process.Name(Nil),
  )
}

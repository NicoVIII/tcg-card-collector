import catalog/application/commands/refresh/ports as refresh_ports
import catalog/application/queries/list_cards/ports as list_cards_ports

pub type Dependencies {
  Dependencies(
    refresh_catalog_ports: refresh_ports.RefreshCatalogPorts,
    list_catalog_cards_port: list_cards_ports.ListCatalogCardsPort,
  )
}

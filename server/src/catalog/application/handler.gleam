import catalog/application/commands/refresh/handler as refresh_handler
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/application/queries/list_cards/handler as list_cards_handler
import catalog/application/queries/list_cards/ports as list_cards_ports

pub type RefreshCatalogResponse {
  Success
  Failed
}

pub fn refresh_catalog(
  ports: refresh_ports.RefreshCatalogPorts,
) -> RefreshCatalogResponse {
  case refresh_handler.execute(refresh_handler.RefreshCatalogCommand, ports) {
    Ok(_) -> Success
    Error(_) -> Failed
  }
}

pub fn list_catalog_cards(
  port: list_cards_ports.ListCatalogCardsPort,
) -> List(list_cards_ports.CatalogCardReadModel) {
  list_cards_handler.execute(list_cards_handler.ListCatalogCardsQuery, port)
}

import application/commands/catalog/refresh/handler as refresh_handler
import application/commands/catalog/refresh/ports as refresh_ports
import application/queries/catalog/list_cards/handler as list_cards_handler
import application/queries/catalog/list_cards/ports as list_cards_ports

pub type RefreshCatalogResponse {
  Success
  Failed
}

pub fn refresh_catalog(
  port: refresh_ports.RefreshCatalogPort,
) -> RefreshCatalogResponse {
  case refresh_handler.execute(refresh_handler.RefreshCatalogCommand, port) {
    Ok(_) -> Success
    Error(_) -> Failed
  }
}

pub fn list_catalog_cards(
  port: list_cards_ports.ListCatalogCardsPort,
) -> List(list_cards_ports.CatalogCardReadModel) {
  list_cards_handler.execute(list_cards_handler.ListCatalogCardsQuery, port)
}

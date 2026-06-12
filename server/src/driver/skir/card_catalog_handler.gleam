import application/commands/database/refresh/handler as refresh_handler
import application/commands/database/refresh/ports as refresh_ports
import application/queries/database/list_cards/handler as list_cards_handler
import application/queries/database/list_cards/ports as list_cards_ports

pub type RefreshCatalogResponse {
  Success
  Failed
}

pub fn refresh_catalog(
  port: refresh_ports.RefreshDatabasePort,
) -> RefreshCatalogResponse {
  case refresh_handler.execute(refresh_handler.RefreshDatabaseCommand, port) {
    Ok(_) -> Success
    Error(_) -> Failed
  }
}

pub fn list_catalog_cards(
  port: list_cards_ports.ListCardsPort,
) -> List(list_cards_ports.DatabaseCardReadModel) {
  list_cards_handler.execute(list_cards_handler.ListDatabaseCardsQuery, port)
}

import application/card_catalog/ports
import driver/skir/card_catalog_handler

pub fn refresh_catalog(
  repository: ports.CatalogRepository,
) -> card_catalog_handler.RefreshCatalogResponse {
  card_catalog_handler.refresh_catalog(repository)
}

pub fn list_catalog_cards(
  repository: ports.CatalogRepository,
) -> List(ports.CatalogCardReadModel) {
  card_catalog_handler.list_catalog_cards(repository)
}

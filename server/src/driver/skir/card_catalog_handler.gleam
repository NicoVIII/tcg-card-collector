import application/card_catalog/ports
import application/card_catalog/service

pub type RefreshCatalogResponse {
  Success
  Error
}

pub fn refresh_catalog(
  repository: ports.CatalogRepository,
) -> RefreshCatalogResponse {
  service.refresh_catalog(repository)
  Success
}

pub fn list_catalog_cards(
  repository: ports.CatalogRepository,
) -> List(ports.CatalogCardReadModel) {
  service.list_catalog_cards(repository)
}

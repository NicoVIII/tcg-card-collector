import application/card_catalog/ports
import application/card_catalog/service

pub type RefreshCatalogResponse {
  Success
  Failed
}

pub fn refresh_catalog(
  repository: ports.CatalogRepository,
) -> RefreshCatalogResponse {
  case service.refresh_catalog(repository) {
    Ok(_) -> Success
    Error(_) -> Failed
  }
}

pub fn list_catalog_cards(
  repository: ports.CatalogRepository,
) -> List(ports.CatalogCardReadModel) {
  service.list_catalog_cards(repository)
}

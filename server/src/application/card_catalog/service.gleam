import application/card_catalog/ports

pub fn refresh_catalog(repository: ports.CatalogRepository) -> Nil {
  ports.refresh(repository)
}

pub fn list_catalog_cards(
  repository: ports.CatalogRepository,
) -> List(ports.CatalogCardReadModel) {
  ports.list(repository)
}

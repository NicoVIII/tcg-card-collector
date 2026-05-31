pub type CatalogCardReadModel {
  CatalogCardReadModel(id: String, name: String, set_code: String)
}

pub type CatalogRefreshError {
  CatalogRefreshError(message: String)
}

pub type CatalogRepository {
  CatalogRepository(
    refresh_catalog: fn() -> Result(Nil, CatalogRefreshError),
    list_cards: fn() -> List(CatalogCardReadModel),
  )
}

pub fn refresh(
  repository: CatalogRepository,
) -> Result(Nil, CatalogRefreshError) {
  let CatalogRepository(refresh_catalog: refresh_catalog, ..) = repository
  refresh_catalog()
}

pub fn list(repository: CatalogRepository) -> List(CatalogCardReadModel) {
  let CatalogRepository(list_cards: list_cards, ..) = repository
  list_cards()
}

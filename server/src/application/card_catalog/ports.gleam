pub type CatalogCardReadModel {
  CatalogCardReadModel(id: String, name: String, set_code: String)
}

pub type CatalogRepository {
  CatalogRepository(
    refresh_catalog: fn() -> Nil,
    list_cards: fn() -> List(CatalogCardReadModel),
  )
}

pub fn refresh(repository: CatalogRepository) -> Nil {
  let CatalogRepository(refresh_catalog: refresh_catalog, ..) = repository
  refresh_catalog()
}

pub fn list(repository: CatalogRepository) -> List(CatalogCardReadModel) {
  let CatalogRepository(list_cards: list_cards, ..) = repository
  list_cards()
}

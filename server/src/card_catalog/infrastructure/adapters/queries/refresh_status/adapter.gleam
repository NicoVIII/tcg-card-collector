import card_catalog/application/queries/refresh_status/ports
import card_catalog/infrastructure/daos/catalog_dao

pub fn new() -> ports.GetCatalogRefreshStatusPort {
  ports.GetCatalogRefreshStatusPort(
    load_refresh_record: catalog_dao.load_refresh_record,
  )
}

import card_catalog/application/queries/get_set_official_sizes/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/dict
import gleam/result

pub fn new() -> ports.GetSetOfficialSizesPort {
  fn(set_codes) {
    catalog_dao.get_set_official_sizes(set_codes)
    |> result.map(dict.from_list)
  }
}

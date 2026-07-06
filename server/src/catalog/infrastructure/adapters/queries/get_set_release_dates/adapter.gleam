import catalog/application/queries/get_set_release_dates/ports
import catalog/infrastructure/daos/catalog_dao
import gleam/dict

pub fn new() -> ports.GetSetReleaseDatesPort {
  fn(set_codes) {
    // Keep '' entries verbatim — "empty means unknown" lives in the domain only.
    catalog_dao.get_set_release_dates(set_codes)
    |> dict.from_list
  }
}

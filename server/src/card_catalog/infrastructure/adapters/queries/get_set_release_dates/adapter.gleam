import card_catalog/application/queries/get_set_release_dates/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/dict
import gleam/result

pub fn new() -> ports.GetSetReleaseDatesPort {
  fn(set_codes) {
    // Keep '' entries verbatim — "empty means unknown" lives in the domain only.
    catalog_dao.get_set_release_dates(set_codes)
    |> result.map(dict.from_list)
  }
}

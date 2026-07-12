import card_catalog/application/queries/get_set_metadata/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/dict
import gleam/list
import gleam/result

pub fn new() -> ports.GetSetMetadataPort {
  fn(set_codes) {
    // Keep '' released_at and NULL→None parent verbatim — the "empty means
    // unknown / root set" reading lives in the domain only.
    use rows <- result.map(catalog_dao.get_set_metadata(set_codes))
    rows
    |> list.map(fn(row) {
      let #(set_code, released_at, parent_set_code) = row
      #(set_code, ports.SetMetadata(released_at:, parent_set_code:))
    })
    |> dict.from_list
  }
}

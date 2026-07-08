import card_catalog/application/queries/get_set_release_dates/ports
import gleam/dict.{type Dict}

pub type GetSetReleaseDatesQuery {
  GetSetReleaseDatesQuery(set_codes: List(String))
}

pub fn execute(
  query: GetSetReleaseDatesQuery,
  port: ports.GetSetReleaseDatesPort,
) -> Result(Dict(String, String), String) {
  port(query.set_codes)
}

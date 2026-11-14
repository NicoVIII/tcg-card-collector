import card_catalog/application/queries/get_set_official_sizes/ports
import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type GetSetOfficialSizesQuery {
  GetSetOfficialSizesQuery(set_codes: List(String))
}

pub fn execute(
  query: GetSetOfficialSizesQuery,
  port: ports.GetSetOfficialSizesPort,
) -> Result(Dict(String, Option(Int)), String) {
  port(query.set_codes)
}

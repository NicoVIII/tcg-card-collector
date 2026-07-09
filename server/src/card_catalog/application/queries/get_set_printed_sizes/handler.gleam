import card_catalog/application/queries/get_set_printed_sizes/ports
import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type GetSetPrintedSizesQuery {
  GetSetPrintedSizesQuery(set_codes: List(String))
}

pub fn execute(
  query: GetSetPrintedSizesQuery,
  port: ports.GetSetPrintedSizesPort,
) -> Result(Dict(String, Option(Int)), String) {
  port(query.set_codes)
}

import card_catalog/application/queries/get_set_metadata/ports
import gleam/dict.{type Dict}

pub type GetSetMetadataQuery {
  GetSetMetadataQuery(set_codes: List(String))
}

pub fn execute(
  query: GetSetMetadataQuery,
  port: ports.GetSetMetadataPort,
) -> Result(Dict(String, ports.SetMetadata), String) {
  port(query.set_codes)
}

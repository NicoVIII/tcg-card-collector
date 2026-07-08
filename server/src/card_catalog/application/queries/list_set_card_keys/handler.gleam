import card_catalog/application/queries/list_set_card_keys/ports
import gleam/dict.{type Dict}

pub type ListSetCardKeysQuery {
  ListSetCardKeysQuery(set_codes: List(String))
}

pub fn execute(
  query: ListSetCardKeysQuery,
  port: ports.ListSetCardKeysPort,
) -> Result(Dict(String, List(String)), String) {
  port.list_set_card_keys(query.set_codes)
}

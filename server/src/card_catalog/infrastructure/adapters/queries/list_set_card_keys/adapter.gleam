import card_catalog/application/queries/list_set_card_keys/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/dict.{type Dict}
import gleam/list
import gleam/result

pub fn new() -> ports.ListSetCardKeysPort {
  ports.ListSetCardKeysPort(list_set_card_keys: list_set_card_keys_adapter())
}

fn list_set_card_keys_adapter() -> fn(List(String)) ->
  Result(Dict(String, List(String)), String) {
  fn(set_codes) {
    use pairs <- result.map(catalog_dao.list_by_set_codes(set_codes))
    pairs
    |> list.group(by: fn(pair) { pair.0 })
    |> dict.map_values(fn(_set_code, pairs) {
      list.map(pairs, fn(pair) { pair.1 })
    })
  }
}

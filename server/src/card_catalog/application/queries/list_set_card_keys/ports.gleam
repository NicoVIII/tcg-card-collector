import gleam/dict.{type Dict}

pub type ListSetCardKeysPort {
  ListSetCardKeysPort(
    list_set_card_keys: fn(List(String)) ->
      Result(Dict(String, List(String)), String),
  )
}

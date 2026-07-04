import gleam/dict
import gleam/list
import gleam/result
import gleam/set
import insights/application/queries/set_completion/ports

pub type SetCompletionQuery {
  SetCompletionQuery
}

pub fn execute(
  _query: SetCompletionQuery,
  ports: ports.SetCompletionPorts,
) -> Result(List(ports.SetCompletionReadModel), String) {
  let target_sets = ports.target_sets()
  let catalog_keys = ports.set_card_keys(target_sets)

  use owned_cards <- result.try(ports.owned_cards())
  let owned =
    owned_cards
    |> list.map(fn(card) { #(card.set_code, card.collector_number) })
    |> set.from_list

  list.map(target_sets, fn(set_code) {
    let collector_numbers =
      dict.get(catalog_keys, set_code) |> result.unwrap([])
    let owned_count =
      collector_numbers
      |> list.filter(fn(cn) { set.contains(owned, #(set_code, cn)) })
      |> list.length

    ports.SetCompletionReadModel(
      set_code: set_code,
      owned: owned_count,
      total: list.length(collector_numbers),
    )
  })
  |> Ok
}

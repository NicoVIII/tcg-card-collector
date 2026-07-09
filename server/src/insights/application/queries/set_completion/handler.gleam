import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
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
  use target_sets <- result.try(ports.target_sets())
  use catalog_keys <- result.try(ports.set_card_keys(target_sets))
  use printed_sizes <- result.try(ports.printed_sizes(target_sets))
  use owned_cards <- result.try(ports.owned_cards())
  let owned =
    owned_cards
    |> list.map(fn(card) { #(card.set_code, card.collector_number) })
    |> set.from_list

  list.map(target_sets, fn(set_code) {
    // Owned cards that actually exist in the catalog for this set (incl. extras).
    let owned_numbers =
      dict.get(catalog_keys, set_code)
      |> result.unwrap([])
      |> list.filter(fn(cn) { set.contains(owned, #(set_code, cn)) })

    case dict.get(printed_sizes, set_code) |> result.unwrap(None) {
      // Official size known: the denominator is printed_size and only cards
      // numbered within 1..printed_size count toward completion (extras excluded).
      Some(size) ->
        ports.SetCompletionReadModel(
          set_code:,
          owned: owned_numbers
            |> list.filter(is_official(_, size))
            |> list.length,
          total: Some(size),
        )
      // No official size: report owned cards (incl. extras) with no denominator.
      None ->
        ports.SetCompletionReadModel(
          set_code:,
          owned: list.length(owned_numbers),
          total: None,
        )
    }
  })
  |> Ok
}

// A card is part of the official set when its collector number parses as an
// integer within 1..printed_size; non-numeric or out-of-range numbers are extras.
fn is_official(collector_number: String, printed_size: Int) -> Bool {
  int.parse(collector_number)
  |> result.map(fn(n) { n >= 1 && n <= printed_size })
  |> result.unwrap(False)
}

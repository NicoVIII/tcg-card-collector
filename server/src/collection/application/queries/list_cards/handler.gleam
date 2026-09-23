import collection/application/queries/list_cards/ports
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/set
import gleam/string
import shared/domain/card_key
import shared/domain/collector_number
import shared/domain/copy_key
import shared/domain/finish
import shared/domain/set_code.{type SetCode}

pub type ListCollectionCardsQuery {
  ListCollectionCardsQuery(
    offset: Int,
    limit: Int,
    name: Option(String),
    set_code: Option(SetCode),
  )
}

pub fn execute(
  query: ListCollectionCardsQuery,
  ports: ports.ListCollectionCardsPorts,
) -> Result(ports.CollectionCardPage, String) {
  use rows <- result.try(ports.list_cards())
  let printings =
    rows
    |> group_by_printing
    |> list.sort(by: compare_printings)
    |> filter_by_set_code(query.set_code)
  use filtered <- result.try(filter_by_name(
    printings,
    query.name,
    ports.card_keys_named,
  ))
  let total = list.length(filtered)
  let paged_printings = paginate_printings(filtered, query.offset, query.limit)
  Ok(ports.CollectionCardPage(printings: paged_printings, total: total))
}

// Groups raw copy rows by the printing they belong to, in first-seen order,
// and orders each printing's copies for display — so a printing owned in
// several kinds of copy becomes one entry with a badge per kind.
fn group_by_printing(
  rows: List(ports.CollectionCopyReadModel),
) -> List(ports.OwnedPrinting) {
  let printing_order =
    rows |> list.map(fn(row) { copy_key.card_key(row.key) }) |> list.unique
  let rows_by_printing =
    list.fold(rows, dict.new(), fn(acc, row) {
      let printing_key = copy_key.card_key(row.key)
      dict.upsert(acc, printing_key, fn(existing) {
        [row, ..option.unwrap(existing, [])]
      })
    })
  list.map(printing_order, fn(printing_key) {
    let copies =
      dict.get(rows_by_printing, printing_key)
      |> result.unwrap([])
      |> list.sort(by: compare_copy_rows)
      |> list.map(to_owned_copy)
    ports.OwnedPrinting(key: printing_key, copies: copies)
  })
}

fn to_owned_copy(row: ports.CollectionCopyReadModel) -> ports.OwnedCopy {
  ports.OwnedCopy(
    finish: copy_key.finish_string(row.key),
    language: copy_key.language_string(row.key),
    quantity: row.quantity,
  )
}

// Badge order within a printing: finish (nonfoil, foil, etched), then
// language code alphabetically. Collection's own display policy — no
// "English first" assumption, since a copy in any language is equally owned.
fn compare_copy_rows(
  a: ports.CollectionCopyReadModel,
  b: ports.CollectionCopyReadModel,
) -> order.Order {
  order.break_tie(
    int.compare(
      finish_rank(copy_key.finish(a.key)),
      finish_rank(copy_key.finish(b.key)),
    ),
    string.compare(
      copy_key.language_string(a.key),
      copy_key.language_string(b.key),
    ),
  )
}

fn finish_rank(value: finish.Finish) -> Int {
  case value {
    finish.Nonfoil -> 0
    finish.Foil -> 1
    finish.Etched -> 2
  }
}

// Physical filing order: set code, then collector number compared numerically
// so "grn 2" precedes "grn 10". The store can't express the numeric-aware order
// on a TEXT column, so the grid's order is decided here.
fn compare_printings(
  a: ports.OwnedPrinting,
  b: ports.OwnedPrinting,
) -> order.Order {
  order.break_tie(
    set_code.compare(card_key.set_code(a.key), card_key.set_code(b.key)),
    collector_number.compare(
      card_key.collector_number(a.key),
      card_key.collector_number(b.key),
    ),
  )
}

// Matches on the printing's own CardKey — an owned printing the catalog
// doesn't carry still matches its set code (ADR 0016).
fn filter_by_set_code(
  printings: List(ports.OwnedPrinting),
  target: Option(SetCode),
) -> List(ports.OwnedPrinting) {
  case target {
    None -> printings
    Some(code) ->
      list.filter(printings, fn(printing) {
        card_key.set_code(printing.key) == code
      })
  }
}

// Reaches into Card Catalog only when a name filter is present (ADR 0016);
// an owned printing absent from the catalog never matches a name.
fn filter_by_name(
  printings: List(ports.OwnedPrinting),
  name: Option(String),
  card_keys_named: ports.CardKeysNamedPort,
) -> Result(List(ports.OwnedPrinting), String) {
  case name {
    None -> Ok(printings)
    Some(query) -> {
      use matching_keys <- result.try(card_keys_named(query))
      Ok(
        list.filter(printings, fn(printing) {
          set.contains(matching_keys, printing.key)
        }),
      )
    }
  }
}

fn paginate_printings(
  printings: List(ports.OwnedPrinting),
  offset: Int,
  limit: Int,
) -> List(ports.OwnedPrinting) {
  let normalized_offset = clamp_non_negative(offset)
  let normalized_limit = clamp_non_negative(limit)

  printings
  |> list.drop(normalized_offset)
  |> fn(remaining) {
    case normalized_limit {
      0 -> remaining
      _ -> list.take(remaining, normalized_limit)
    }
  }
}

fn clamp_non_negative(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

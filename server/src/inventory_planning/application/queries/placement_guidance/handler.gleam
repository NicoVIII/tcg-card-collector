import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import inventory_planning/application/queries/placement_guidance/ports
import inventory_planning/application/queries/projection/ports as projection_ports

pub type GetPlacementGuidanceQuery {
  GetPlacementGuidanceQuery
}

pub fn execute(
  _query: GetPlacementGuidanceQuery,
  ports_bundle: ports.GetPlacementGuidancePorts,
) -> Result(ports.PlacementGuidance, String) {
  use projection <- result.try(ports_bundle.projection())
  use placed_rows <- result.try(ports_bundle.placed_cards())

  let placed_at = index_placed_at(placed_rows)
  let placed_total = index_placed_total(placed_rows)

  let locations =
    projection.locations
    |> list.filter_map(fn(location) {
      build_location(location, placed_at) |> option.to_result(Nil)
    })

  Ok(ports.PlacementGuidance(
    locations: locations,
    total_unplaced: total_unplaced(projection.locations, placed_total),
  ))
}

// --- Placed-ledger indexes ------------------------------------------------

fn index_placed_at(
  rows: List(ports.PlacedCardRow),
) -> Dict(#(String, String, String), Int) {
  list.fold(rows, dict.new(), fn(acc, row) {
    dict.upsert(
      acc,
      #(row.set_code, row.collector_number, row.location),
      fn(existing) { option.unwrap(existing, 0) + row.quantity },
    )
  })
}

fn index_placed_total(
  rows: List(ports.PlacedCardRow),
) -> Dict(#(String, String), Int) {
  list.fold(rows, dict.new(), fn(acc, row) {
    dict.upsert(acc, #(row.set_code, row.collector_number), fn(existing) {
      option.unwrap(existing, 0) + row.quantity
    })
  })
}

fn placed_at_qty(
  placed_at: Dict(#(String, String, String), Int),
  card: projection_ports.ProjectionCard,
  location_name: String,
) -> Int {
  dict.get(placed_at, #(card.set_code, card.collector_number, location_name))
  |> result.unwrap(0)
}

// --- Per-location guidance ------------------------------------------------

fn build_location(
  location: projection_ports.ProjectionLocation,
  placed_at: Dict(#(String, String, String), Int),
) -> option.Option(ports.PlacementLocation) {
  let cards = location.cards

  let placement_cards =
    cards
    |> list.index_map(fn(card, index) { #(index, card) })
    |> list.filter_map(fn(pair) {
      let #(index, card) = pair
      let to_place =
        int.max(
          0,
          card.quantity - placed_at_qty(placed_at, card, location.location_name),
        )
      case to_place > 0 {
        False -> Error(Nil)
        True ->
          Ok(ports.PlacementCard(
            name: card.name,
            set_code: card.set_code,
            collector_number: card.collector_number,
            to_place_quantity: to_place,
            before: neighbors(
              cards |> list.take(index) |> list.drop(int.max(0, index - 2)),
              placed_at,
              location.location_name,
            ),
            after: neighbors(
              cards |> list.drop(index + 1) |> list.take(2),
              placed_at,
              location.location_name,
            ),
          ))
      }
    })

  case placement_cards {
    [] -> None
    _ ->
      Some(ports.PlacementLocation(
        location_name: location.location_name,
        total_quantity: list.fold(placement_cards, 0, fn(sum, card) {
          sum + card.to_place_quantity
        }),
        cards: placement_cards,
      ))
  }
}

fn neighbors(
  cards: List(projection_ports.ProjectionCard),
  placed_at: Dict(#(String, String, String), Int),
  location_name: String,
) -> List(ports.PlacementNeighbor) {
  list.map(cards, fn(card) {
    ports.PlacementNeighbor(
      name: card.name,
      set_code: card.set_code,
      collector_number: card.collector_number,
      already_placed: placed_at_qty(placed_at, card, location_name) > 0,
    )
  })
}

// --- Grand total ----------------------------------------------------------

// Quantity is conserved across the cascade, so the collection total per key is
// the sum of its projected copies; unplaced is that minus what's been placed,
// clamped at zero and summed.
fn total_unplaced(
  locations: List(projection_ports.ProjectionLocation),
  placed_total: Dict(#(String, String), Int),
) -> Int {
  let projected_total =
    list.fold(locations, dict.new(), fn(acc, location) {
      list.fold(location.cards, acc, fn(inner, card) {
        dict.upsert(
          inner,
          #(card.set_code, card.collector_number),
          fn(existing) { option.unwrap(existing, 0) + card.quantity },
        )
      })
    })

  dict.fold(projected_total, 0, fn(sum, key, projected) {
    sum
    + int.max(
      0,
      projected - { dict.get(placed_total, key) |> result.unwrap(0) },
    )
  })
}

import inventory_planning/application/queries/projection/ports as projection_ports

// --- Read models ----------------------------------------------------------

// A card adjacent to an unplaced one in its location's cascade order, shown so
// the user can find where the new copy goes. `already_placed` distinguishes a
// neighbor that is physically there from one that is itself still to place.
pub type PlacementNeighbor {
  PlacementNeighbor(
    name: String,
    set_code: String,
    collector_number: String,
    already_placed: Bool,
  )
}

// A card with copies still to place in this location: `to_place_quantity` is
// projected minus already-placed here, with the neighbors on either side.
pub type PlacementCard {
  PlacementCard(
    name: String,
    set_code: String,
    collector_number: String,
    to_place_quantity: Int,
    before: List(PlacementNeighbor),
    after: List(PlacementNeighbor),
  )
}

// A location holding unplaced cards, in cascade order. `total_quantity` is the
// sum of copies still to place across its cards.
pub type PlacementLocation {
  PlacementLocation(
    location_name: String,
    total_quantity: Int,
    cards: List(PlacementCard),
  )
}

// The whole guidance: locations still needing placement work (cascade order,
// empty ones dropped) and the grand total of unplaced copies across the
// collection.
pub type PlacementGuidance {
  PlacementGuidance(locations: List(PlacementLocation), total_unplaced: Int)
}

// --- Driven ports ---------------------------------------------------------

// One row of the placed ledger: how many copies of a key sit in a location.
pub type PlacedCardRow {
  PlacedCardRow(
    set_code: String,
    collector_number: String,
    location: String,
    quantity: Int,
  )
}

// Reuses the projection read model (the legal capability-narrow reuse): guidance
// is derived by subtracting the placed ledger from the projection.
pub type GetPlacementGuidancePorts {
  GetPlacementGuidancePorts(
    projection: fn() -> Result(projection_ports.Projection, String),
    placed_cards: fn() -> Result(List(PlacedCardRow), String),
  )
}

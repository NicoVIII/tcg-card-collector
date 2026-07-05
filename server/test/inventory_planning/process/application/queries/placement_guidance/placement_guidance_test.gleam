import gleam/list
import inventory_planning/application/queries/placement_guidance/handler
import inventory_planning/application/queries/placement_guidance/ports
import inventory_planning/application/queries/projection/ports as projection_ports

fn build_ports(
  projection projection: projection_ports.Projection,
  placed placed: List(ports.PlacedCardRow),
) -> ports.GetPlacementGuidancePorts {
  ports.GetPlacementGuidancePorts(
    projection: fn() { Ok(projection) },
    placed_cards: fn() { Ok(placed) },
  )
}

fn placed(
  set_code: String,
  collector_number: String,
  location: String,
  quantity: Int,
) -> ports.PlacedCardRow {
  ports.PlacedCardRow(
    set_code: set_code,
    collector_number: collector_number,
    location: location,
    quantity: quantity,
  )
}

fn pcard(
  name name: String,
  set_code set_code: String,
  collector_number collector_number: String,
  quantity quantity: Int,
) -> projection_ports.ProjectionCard {
  projection_ports.ProjectionCard(
    name: name,
    set_code: set_code,
    collector_number: collector_number,
    quantity: quantity,
    color_identity: "",
    rarity: "",
    card_type: "",
  )
}

fn ploc(
  location_name location_name: String,
  cards cards: List(projection_ports.ProjectionCard),
) -> projection_ports.ProjectionLocation {
  projection_ports.ProjectionLocation(
    location_name: location_name,
    rule_id: "",
    total_quantity: list.fold(cards, 0, fn(s, c) { s + c.quantity }),
    cards: cards,
  )
}

fn projection(
  locations: List(projection_ports.ProjectionLocation),
) -> projection_ports.Projection {
  projection_ports.Projection(
    locations: locations,
    total_quantity: 0,
    unknown_count: 0,
  )
}

// The copy-split case: 4 bolts, projected 1 to a set binder and 3 to bulk. The
// ledger has 1 in the binder (fully placed there) and 2 in bulk, so only 1 bulk
// copy remains — attribution is exact per (card, location).
pub fn copy_split_attributes_remaining_to_the_right_location_test() {
  let ports =
    build_ports(
      projection: projection([
        ploc(location_name: "Binder", cards: [
          pcard(
            name: "Lightning Bolt",
            set_code: "lea",
            collector_number: "161",
            quantity: 1,
          ),
        ]),
        ploc(location_name: "Bulk", cards: [
          pcard(
            name: "Lightning Bolt",
            set_code: "lea",
            collector_number: "161",
            quantity: 3,
          ),
        ]),
      ]),
      placed: [
        placed("lea", "161", "Binder", 1),
        placed("lea", "161", "Bulk", 2),
      ],
    )

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Ok(
      ports.PlacementGuidance(total_unplaced: 1, locations: [
        ports.PlacementLocation(
          location_name: "Bulk",
          total_quantity: 1,
          cards: [
            ports.PlacementCard(
              name: "Lightning Bolt",
              set_code: "lea",
              collector_number: "161",
              to_place_quantity: 1,
              before: [],
              after: [],
            ),
          ],
        ),
      ]),
    )
}

// Neighbors are drawn from the full cascade order of the location (up to 2 each
// side), and each is flagged placed or not — including a still-new neighbor.
pub fn neighbors_carry_position_and_placed_flags_test() {
  let ports =
    build_ports(
      projection: projection([
        ploc(location_name: "Bulk", cards: [
          pcard(name: "A", set_code: "lea", collector_number: "1", quantity: 1),
          pcard(name: "B", set_code: "lea", collector_number: "2", quantity: 1),
          pcard(name: "C", set_code: "lea", collector_number: "3", quantity: 1),
          pcard(name: "D", set_code: "lea", collector_number: "4", quantity: 1),
          pcard(name: "E", set_code: "lea", collector_number: "5", quantity: 1),
        ]),
      ]),
      placed: [placed("lea", "1", "Bulk", 1), placed("lea", "4", "Bulk", 1)],
    )

  let placed_neighbor = fn(name, number) {
    ports.PlacementNeighbor(
      name: name,
      set_code: "lea",
      collector_number: number,
      already_placed: True,
    )
  }
  let new_neighbor = fn(name, number) {
    ports.PlacementNeighbor(
      name: name,
      set_code: "lea",
      collector_number: number,
      already_placed: False,
    )
  }

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Ok(
      ports.PlacementGuidance(total_unplaced: 3, locations: [
        ports.PlacementLocation(
          location_name: "Bulk",
          total_quantity: 3,
          cards: [
            ports.PlacementCard(
              name: "B",
              set_code: "lea",
              collector_number: "2",
              to_place_quantity: 1,
              before: [placed_neighbor("A", "1")],
              after: [new_neighbor("C", "3"), placed_neighbor("D", "4")],
            ),
            ports.PlacementCard(
              name: "C",
              set_code: "lea",
              collector_number: "3",
              to_place_quantity: 1,
              before: [placed_neighbor("A", "1"), new_neighbor("B", "2")],
              after: [placed_neighbor("D", "4"), new_neighbor("E", "5")],
            ),
            ports.PlacementCard(
              name: "E",
              set_code: "lea",
              collector_number: "5",
              to_place_quantity: 1,
              before: [new_neighbor("C", "3"), placed_neighbor("D", "4")],
              after: [],
            ),
          ],
        ),
      ]),
    )
}

pub fn over_placed_cards_clamp_to_zero_and_drop_the_location_test() {
  let ports =
    build_ports(
      projection: projection([
        ploc(location_name: "Bulk", cards: [
          pcard(
            name: "Bolt",
            set_code: "lea",
            collector_number: "1",
            quantity: 2,
          ),
        ]),
      ]),
      placed: [placed("lea", "1", "Bulk", 5)],
    )

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Ok(ports.PlacementGuidance(total_unplaced: 0, locations: []))
}

pub fn empty_ledger_leaves_everything_unplaced_test() {
  let ports =
    build_ports(
      projection: projection([
        ploc(location_name: "Bulk", cards: [
          pcard(
            name: "Bolt",
            set_code: "lea",
            collector_number: "1",
            quantity: 2,
          ),
        ]),
      ]),
      placed: [],
    )

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Ok(
      ports.PlacementGuidance(total_unplaced: 2, locations: [
        ports.PlacementLocation(
          location_name: "Bulk",
          total_quantity: 2,
          cards: [
            ports.PlacementCard(
              name: "Bolt",
              set_code: "lea",
              collector_number: "1",
              to_place_quantity: 2,
              before: [],
              after: [],
            ),
          ],
        ),
      ]),
    )
}

pub fn fully_placed_collection_has_no_guidance_test() {
  let ports =
    build_ports(
      projection: projection([
        ploc(location_name: "Bulk", cards: [
          pcard(
            name: "Bolt",
            set_code: "lea",
            collector_number: "1",
            quantity: 2,
          ),
        ]),
      ]),
      placed: [placed("lea", "1", "Bulk", 2)],
    )

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Ok(ports.PlacementGuidance(total_unplaced: 0, locations: []))
}

pub fn projection_error_propagates_test() {
  let ports =
    ports.GetPlacementGuidancePorts(
      projection: fn() { Error("projection unavailable") },
      placed_cards: fn() { Ok([]) },
    )

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Error("projection unavailable")
}

pub fn placed_ledger_error_propagates_test() {
  let ports =
    ports.GetPlacementGuidancePorts(
      projection: fn() { Ok(projection([])) },
      placed_cards: fn() { Error("ledger unavailable") },
    )

  assert handler.execute(handler.GetPlacementGuidanceQuery, ports)
    == Error("ledger unavailable")
}

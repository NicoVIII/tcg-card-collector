import gleam/list
import gleam/result
import inventory_planning/application/queries/placement_guidance/ports
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/infrastructure/adapters/queries/projection/adapter as projection_adapter
import inventory_planning/infrastructure/daos/placed_cards_dao

pub fn new() -> ports.GetPlacementGuidancePorts {
  ports.GetPlacementGuidancePorts(
    projection: projection_port(),
    placed_cards: placed_cards_port(),
  )
}

// Reuse composed in infrastructure: the projection is another query handler run
// through its own adapter, not a widened port shared into this use case.
fn projection_port() -> fn() -> Result(projection_ports.Projection, String) {
  fn() {
    projection_handler.execute(
      projection_handler.InventoryProjectionQuery,
      projection_adapter.new(),
    )
  }
}

fn placed_cards_port() -> fn() -> Result(List(ports.PlacedCardRow), String) {
  fn() {
    use rows <- result.try(placed_cards_dao.list())
    Ok(
      list.map(rows, fn(row) {
        let #(set_code, collector_number, location, quantity) = row
        ports.PlacedCardRow(set_code:, collector_number:, location:, quantity:)
      }),
    )
  }
}

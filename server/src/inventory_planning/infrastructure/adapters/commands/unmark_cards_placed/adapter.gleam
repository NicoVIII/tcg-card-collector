import gleam/list
import inventory_planning/application/commands/unmark_cards_placed/ports
import inventory_planning/infrastructure/daos/placed_cards_dao

pub fn new() -> ports.UnmarkCardsPlacedPort {
  fn(write_models) {
    placed_cards_dao.decrement(list.map(write_models, to_row))
  }
}

fn to_row(model: ports.PlacementWriteModel) -> placed_cards_dao.PlacedCardRow {
  placed_cards_dao.PlacedCardRow(
    set_code: model.set_code,
    collector_number: model.collector_number,
    finish: model.finish,
    language: model.language,
    location: model.location,
    quantity: model.quantity,
  )
}

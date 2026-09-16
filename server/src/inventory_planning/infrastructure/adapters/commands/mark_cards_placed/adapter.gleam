import gleam/list
import inventory_planning/application/commands/mark_cards_placed/ports
import inventory_planning/infrastructure/daos/placed_cards_dao

pub fn new() -> ports.MarkCardsPlacedPort {
  fn(write_models) {
    placed_cards_dao.increment(list.map(write_models, to_row))
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

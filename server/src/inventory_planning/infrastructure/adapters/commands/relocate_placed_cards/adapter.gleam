import inventory_planning/application/commands/relocate_placed_cards/ports
import inventory_planning/infrastructure/daos/placed_cards_dao

pub fn new() -> ports.RelocatePlacedCardsPort {
  fn(model: ports.RelocationWriteModel) {
    placed_cards_dao.relocate(model.from, model.to)
  }
}

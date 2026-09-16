import collection/application/queries/list_cards/handler as list_cards_handler
import collection/application/queries/list_cards/ports as list_cards_ports

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import collection/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter
import gleam/list
import gleam/result
import shared/domain/card_key.{type CardKey}

// A printing and how many copies of it are owned in total, added up across
// finish and language (ADR 0010: consumers that care only about the printing
// add up across CopyKeys — this facade is that reduction for other contexts).
pub type OwnedCard {
  OwnedCard(key: CardKey, quantity: Int)
}

pub fn list_cards() -> Result(List(OwnedCard), String) {
  use page <- result.try(list_cards_handler.execute(
    list_cards_handler.ListCollectionCardsQuery(offset: 0, limit: 0),
    list_cards_adapter.new(),
  ))
  Ok(list.map(page.printings, to_owned_card))
}

fn to_owned_card(printing: list_cards_ports.OwnedPrinting) -> OwnedCard {
  let quantity =
    list.fold(printing.copies, 0, fn(sum, copy) { sum + copy.quantity })
  OwnedCard(key: printing.key, quantity:)
}

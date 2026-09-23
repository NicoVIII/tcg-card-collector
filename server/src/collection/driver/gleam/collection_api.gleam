import collection/application/queries/list_cards/handler as list_cards_handler
import collection/application/queries/list_cards/ports as list_cards_ports

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import collection/infrastructure/adapters/queries/list_cards/adapter as list_cards_adapter
import gleam/list
import gleam/option.{None}
import gleam/result
import shared/domain/card_key.{type CardKey}
import shared/domain/copy_key.{type CopyKey}

// A printing and how many copies of it are owned in total, added up across
// finish and language (ADR 0010: consumers that care only about the printing
// add up across CopyKeys — this facade is that reduction for other contexts).
pub type OwnedCard {
  OwnedCard(key: CardKey, quantity: Int)
}

// One kind of owned copy — the identity placement needs to say which copy of
// a printing a tick names (ADR 0010).
pub type OwnedCopy {
  OwnedCopy(key: CopyKey, quantity: Int)
}

fn fetch_page() -> Result(list_cards_ports.CollectionCardPage, String) {
  list_cards_handler.execute(
    list_cards_handler.ListCollectionCardsQuery(
      offset: 0,
      limit: 0,
      name: None,
      set_code: None,
    ),
    list_cards_adapter.new(),
  )
}

pub fn list_cards() -> Result(List(OwnedCard), String) {
  use page <- result.try(fetch_page())
  Ok(list.map(page.printings, to_owned_card))
}

pub fn list_copies() -> Result(List(OwnedCopy), String) {
  use page <- result.try(fetch_page())
  Ok(list.flat_map(page.printings, to_owned_copies))
}

fn to_owned_card(printing: list_cards_ports.OwnedPrinting) -> OwnedCard {
  let quantity =
    list.fold(printing.copies, 0, fn(sum, copy) { sum + copy.quantity })
  OwnedCard(key: printing.key, quantity:)
}

fn to_owned_copies(
  printing: list_cards_ports.OwnedPrinting,
) -> List(OwnedCopy) {
  list.filter_map(printing.copies, fn(copy) {
    case
      copy_key.new(
        set_code: card_key.set_code_string(printing.key),
        collector_number: card_key.collector_number_string(printing.key),
        finish: copy.finish,
        language: copy.language,
      )
    {
      Ok(key) -> Ok(OwnedCopy(key:, quantity: copy.quantity))
      // The list_cards query only ever produces canonical finish/language
      // strings (parsed at the DAO boundary), so this branch is unreachable
      // in practice; skipping rather than crashing keeps the port total.
      Error(_) -> Error(Nil)
    }
  })
}

import domain/catalog/card_printing.{type CardPrintingId}

pub type PhysicalCard {
  PhysicalCard(id: String, card_printing_id: CardPrintingId)
}

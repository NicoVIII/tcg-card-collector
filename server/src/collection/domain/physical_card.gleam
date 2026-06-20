import shared/domain/card_key.{type CardKey}

pub type PhysicalCard {
  PhysicalCard(key: CardKey, quantity: Int)
}

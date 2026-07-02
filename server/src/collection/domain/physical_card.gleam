import shared/domain/card_key.{type CardKey}

pub type Quantity {
  Quantity(Int)
}

pub type QuantityError {
  QuantityNotPositive
}

pub fn quantity_new(value: Int) -> Result(Quantity, QuantityError) {
  case value > 0 {
    True -> Ok(Quantity(value))
    False -> Error(QuantityNotPositive)
  }
}

pub fn quantity_to_int(quantity: Quantity) -> Int {
  let Quantity(value) = quantity
  value
}

pub type PhysicalCard {
  PhysicalCard(key: CardKey, quantity: Quantity)
}

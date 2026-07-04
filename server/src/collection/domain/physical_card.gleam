import shared/domain/card_key.{type CardKey}

pub opaque type Quantity {
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

/// Sums two quantities. Closed over Quantity: both operands are already
/// positive, so the sum is too.
pub fn quantity_add(a: Quantity, b: Quantity) -> Quantity {
  Quantity(quantity_to_int(a) + quantity_to_int(b))
}

pub type PhysicalCard {
  PhysicalCard(key: CardKey, quantity: Quantity)
}

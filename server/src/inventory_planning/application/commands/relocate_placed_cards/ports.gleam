// A validated, canonicalized relocation ready to persist. The handler
// produces this from the raw request via the placement domain's Relocation
// type.
pub type RelocationWriteModel {
  RelocationWriteModel(from: String, to: String)
}

pub type RelocatePlacedCardsPort =
  fn(RelocationWriteModel) -> Result(Nil, String)

pub type RelocatePlacedCardsError {
  InvalidRelocation
  PersistenceFailed(reason: String)
}

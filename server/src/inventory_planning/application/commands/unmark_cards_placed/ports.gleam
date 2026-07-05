// A validated, canonicalized placement to remove. The handler produces these
// from raw request rows via the placement domain type.
pub type PlacementWriteModel {
  PlacementWriteModel(
    set_code: String,
    collector_number: String,
    location: String,
    quantity: Int,
  )
}

pub type UnmarkCardsPlacedPort =
  fn(List(PlacementWriteModel)) -> Result(Nil, String)

pub type UnmarkCardsPlacedError {
  InvalidPlacements
  PersistenceFailed(reason: String)
}

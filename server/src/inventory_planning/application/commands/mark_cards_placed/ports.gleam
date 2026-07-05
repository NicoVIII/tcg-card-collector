// A validated, canonicalized placement ready to persist. The handler produces
// these from raw request rows via the placement domain type.
pub type PlacementWriteModel {
  PlacementWriteModel(
    set_code: String,
    collector_number: String,
    location: String,
    quantity: Int,
  )
}

pub type MarkCardsPlacedPort =
  fn(List(PlacementWriteModel)) -> Result(Nil, String)

pub type MarkCardsPlacedError {
  InvalidPlacements
  PersistenceFailed(reason: String)
}

import gleam/string

// The closed set of physical finishes a copy can be printed in (ADR 0010).
// No ordering here — a total order over Finish is Inventory Planning policy.
// Owned finish isn't validated against what the catalog lists for a printing:
// the catalog states facts, not constraints on what someone may own.
pub type Finish {
  Nonfoil
  Foil
  Etched
}

pub type FinishError {
  Unknown
}

/// Strict constructor — accepts only the canonical lowercase spelling. Use
/// from_user_input when the value comes from human-supplied text.
pub fn new(raw: String) -> Result(Finish, FinishError) {
  case raw {
    "nonfoil" -> Ok(Nonfoil)
    "foil" -> Ok(Foil)
    "etched" -> Ok(Etched)
    _ -> Error(Unknown)
  }
}

/// Lenient constructor for user-supplied text: trims and lowercases first.
pub fn from_user_input(raw: String) -> Result(Finish, FinishError) {
  new(raw |> string.trim |> string.lowercase)
}

pub fn to_string(finish: Finish) -> String {
  case finish {
    Nonfoil -> "nonfoil"
    Foil -> "foil"
    Etched -> "etched"
  }
}

pub type ImportMode {
  Full
  Delta
}

pub fn to_string(mode: ImportMode) -> String {
  case mode {
    Full -> "full"
    Delta -> "delta"
  }
}

pub fn parse(raw: String) -> Result(ImportMode, Nil) {
  case raw {
    "full" -> Ok(Full)
    "delta" -> Ok(Delta)
    _ -> Error(Nil)
  }
}

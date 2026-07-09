import gleam/dict.{type Dict}
import gleam/option.{type Option}

// A set missing from the catalog, or one Scryfall gives no printed_size for,
// maps to None (no official size). A read *error* is a genuine failure and
// propagates rather than masquerading as "no size known".
pub type GetSetPrintedSizesPort =
  fn(List(String)) -> Result(Dict(String, Option(Int)), String)

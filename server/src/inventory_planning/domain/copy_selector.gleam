import gleam/option.{type Option, None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard}
import shared/domain/oracle_id

// How many copies of a matching card a rule claims.
pub type CopySelector {
  // Every remaining copy.
  AllCopies
  // The first remaining copy of each distinct printing.
  FirstCopyPerPrinting
  // The first remaining copy of each distinct oracle identity.
  FirstCopyPerOracle
}

pub fn parse(raw: String) -> Result(CopySelector, Nil) {
  case raw {
    "all" -> Ok(AllCopies)
    "first_per_printing" -> Ok(FirstCopyPerPrinting)
    "first_per_oracle" -> Ok(FirstCopyPerOracle)
    _ -> Error(Nil)
  }
}

pub fn to_string(selector: CopySelector) -> String {
  case selector {
    AllCopies -> "all"
    FirstCopyPerPrinting -> "first_per_printing"
    FirstCopyPerOracle -> "first_per_oracle"
  }
}

// The identity a first-copy selector dedupes on, or None for AllCopies (which
// never gates). FirstCopyPerOracle falls back to the printing key when the card
// carries no oracle_id (reversible/multi-face gaps), so it still dedupes sanely.
pub fn identity(selector: CopySelector, card: PlannedCard) -> Option(String) {
  case selector {
    AllCopies -> None
    FirstCopyPerPrinting -> Some(card_attributes.printing_key(card))
    FirstCopyPerOracle ->
      case card.oracle_id {
        None -> Some(card_attributes.printing_key(card))
        Some(oracle) -> Some("oracle:" <> oracle_id.to_string(oracle))
      }
  }
}

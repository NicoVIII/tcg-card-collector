import gleam/option.{None, Some}
import inventory_planning/domain/card_attributes.{type PlannedCard} as attrs
import inventory_planning/domain/copy_selector.{
  AllCopies, FirstCopyPerOracle, FirstCopyPerPrinting,
}
import shared/domain/card_key
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date

fn card(oracle: option.Option(String)) -> PlannedCard {
  let assert Ok(key) =
    card_key.from_user_input(set_code: "grn", collector_number: "173")
  let assert Ok(date) = release_date.parse("2018-10-05")
  attrs.PlannedCard(
    key:,
    name: "Test",
    quantity: 1,
    released_at: Some(date),
    oracle_id: option.then(oracle, fn(raw) {
      option.from_result(oracle_id.new(raw))
    }),
    rarity: Some(rarity.Rare),
    color_identity: None,
    card_type: None,
  )
}

pub fn parse_round_trip_test() {
  let all = [AllCopies, FirstCopyPerPrinting, FirstCopyPerOracle]
  assert list_all_round_trip(all)
}

fn list_all_round_trip(selectors: List(copy_selector.CopySelector)) -> Bool {
  case selectors {
    [] -> True
    [s, ..rest] ->
      case copy_selector.parse(copy_selector.to_string(s)) == Ok(s) {
        True -> list_all_round_trip(rest)
        False -> False
      }
  }
}

pub fn all_copies_has_no_identity_test() {
  assert copy_selector.identity(AllCopies, card(Some("o1"))) == None
}

pub fn per_printing_identity_is_key_test() {
  assert copy_selector.identity(FirstCopyPerPrinting, card(Some("o1")))
    == Some("grn/173")
}

pub fn per_oracle_identity_uses_oracle_test() {
  assert copy_selector.identity(FirstCopyPerOracle, card(Some("o1")))
    == Some("oracle:o1")
}

// A missing oracle_id falls back to the printing key, so the selector still
// dedupes sanely for reversible/multi-face gaps. (An *empty* oracle id is
// unrepresentable since OracleId became a shared value type.)
pub fn per_oracle_falls_back_to_printing_key_test() {
  assert copy_selector.identity(FirstCopyPerOracle, card(None))
    == Some("grn/173")
}

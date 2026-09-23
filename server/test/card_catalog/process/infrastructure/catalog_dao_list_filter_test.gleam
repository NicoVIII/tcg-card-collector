import card_catalog/infrastructure/daos/catalog_dao
import gleam/option.{None, Some}
import shared/infrastructure/stores/sqlite_store
import sqlight
import support/test_db

fn insert_card(
  set_code set_code: String,
  collector_number collector_number: String,
  name name: String,
) -> Nil {
  let assert Ok(Nil) =
    sqlite_store.exec(
      "INSERT INTO catalog_cards "
        <> "(id, name, set_code, collector_number, rarity, image_uri) "
        <> "VALUES (?, ?, ?, ?, 'common', '');",
      [
        sqlight.text(set_code <> "-" <> collector_number),
        sqlight.text(name),
        sqlight.text(set_code),
        sqlight.text(collector_number),
      ],
    )
  Nil
}

// Names are deliberately ordered "Boros" < "Counterspell" < "Lightning" so
// the name-ASC ordering assertions below are unambiguous.
fn seed_cards() -> Nil {
  insert_card(set_code: "grn", collector_number: "1", name: "Boros Bolt-Hound")
  insert_card(set_code: "lea", collector_number: "2", name: "Counterspell")
  insert_card(set_code: "lea", collector_number: "1", name: "Lightning Bolt")
}

pub fn no_filter_returns_every_card_in_name_order_test() {
  use _db <- test_db.with_temp_db()
  seed_cards()

  let assert Ok(rows) = catalog_dao.list(None, None)

  assert rows == [#("grn", "1"), #("lea", "2"), #("lea", "1")]
}

pub fn name_filter_matches_case_insensitive_substring_test() {
  use _db <- test_db.with_temp_db()
  seed_cards()

  let assert Ok(rows) = catalog_dao.list(Some("bolt"), None)

  assert rows == [#("grn", "1"), #("lea", "1")]
}

pub fn set_code_filter_is_exact_test() {
  use _db <- test_db.with_temp_db()
  seed_cards()

  let assert Ok(rows) = catalog_dao.list(None, Some("lea"))

  assert rows == [#("lea", "2"), #("lea", "1")]
}

pub fn both_filters_combine_with_and_test() {
  use _db <- test_db.with_temp_db()
  seed_cards()

  let assert Ok(rows) = catalog_dao.list(Some("bolt"), Some("lea"))

  assert rows == [#("lea", "1")]
}

// instr(), not LIKE, backs the match — '%' and '_' need no escaping and stay
// literal characters in the search term.
pub fn name_filter_treats_percent_and_underscore_as_literal_test() {
  use _db <- test_db.with_temp_db()
  insert_card(set_code: "mh1", collector_number: "1", name: "100% Bolt_Proof")

  let assert Ok(exact) = catalog_dao.list(Some("100% Bolt_Proof"), None)
  assert exact == [#("mh1", "1")]

  let assert Ok(literal_underscore) = catalog_dao.list(Some("_Proof"), None)
  assert literal_underscore == [#("mh1", "1")]

  let assert Ok(underscore_is_not_a_wildcard) =
    catalog_dao.list(Some("XProof"), None)
  assert underscore_is_not_a_wildcard == []
}

import card_catalog/domain/card_set.{CardSet}
import card_catalog/infrastructure/daos/catalog_dao
import gleam/option.{None}
import support/test_db

fn set(code: String) -> card_set.CardSet {
  CardSet(
    code:,
    name: "Set " <> code,
    released_at: None,
    card_count: 1,
    printed_size: None,
    icon_svg_uri: "",
    parent_set_code: None,
  )
}

pub fn replace_sets_round_trip_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = catalog_dao.replace_sets([set("lea"), set("grn")])
  let assert Ok(Nil) = catalog_dao.replace_sets([set("2xm")])

  assert catalog_dao.get_set_metadata(["lea", "grn", "2xm"])
    == Ok([#("2xm", "", None)])
}

// Regression: a failing replace must not leave the table empty (found
// 2026-07-12 when an unapplied migration made every insert fail and the
// previous 1043 sets were wiped). A duplicate set_code violates the primary
// key mid-insert; the previously stored sets must survive.
pub fn failed_replace_keeps_previous_sets_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = catalog_dao.replace_sets([set("lea"), set("grn")])

  let assert Error(_) = catalog_dao.replace_sets([set("2xm"), set("2xm")])

  assert catalog_dao.get_set_metadata(["lea", "grn", "2xm"])
    == Ok([#("grn", "", None), #("lea", "", None)])
}

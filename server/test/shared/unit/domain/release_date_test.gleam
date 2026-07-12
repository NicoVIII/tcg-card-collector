import gleam/list
import gleam/order
import shared/domain/release_date

pub fn parses_iso_date_and_round_trips_test() {
  let assert Ok(date) = release_date.parse("2018-10-05")
  assert release_date.to_string(date) == "2018-10-05"
}

pub fn trims_surrounding_whitespace_test() {
  let assert Ok(date) = release_date.parse(" 2018-10-05 ")
  assert release_date.to_string(date) == "2018-10-05"
}

pub fn rejects_malformed_dates_test() {
  let malformed = [
    "",
    "2018",
    "2018-10",
    "10-05-2018",
    "2018/10/05",
    "2018-1-05",
    "2018-10-5",
    "-018-10-05",
    "yyyy-mm-dd",
    "2018-10-05T00:00:00Z",
  ]
  assert list.all(malformed, fn(raw) { release_date.parse(raw) == Error(Nil) })
}

pub fn compares_chronologically_test() {
  let assert Ok(older) = release_date.parse("1993-08-05")
  let assert Ok(newer) = release_date.parse("2020-01-01")
  assert release_date.compare(older, newer) == order.Lt
  assert release_date.compare(newer, older) == order.Gt
  assert release_date.compare(older, older) == order.Eq
}

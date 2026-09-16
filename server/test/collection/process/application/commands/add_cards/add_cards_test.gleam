import collection/application/commands/add_cards/handler
import collection/application/commands/add_cards/ports
import gleam/list
import gleam/option.{type Option, None, Some}
import shared/domain/copy_key
import support/ref

fn build_upsert_cards(
  written written: ref.Ref(Option(List(ports.CollectionRowWriteModel))),
  result result: Result(Nil, String),
) -> ports.UpsertCardsPort {
  fn(rows) {
    case result {
      Ok(Nil) -> {
        ref.set(written, Some(rows))
        Ok(Nil)
      }
      Error(reason) -> Error(reason)
    }
  }
}

fn row(
  set_code set_code: String,
  collector_number collector_number: String,
  quantity quantity: Int,
) -> ports.AddCardsRow {
  ports.AddCardsRow(
    set_code:,
    collector_number:,
    finish: "nonfoil",
    language: "en",
    quantity:,
  )
}

fn assert_copy_key(
  set_code: String,
  collector_number: String,
  finish: String,
  language: String,
) -> copy_key.CopyKey {
  let assert Ok(key) =
    copy_key.new(set_code:, collector_number:, finish:, language:)
  key
}

fn quantity_for(
  rows: List(ports.CollectionRowWriteModel),
  set_code: String,
  collector_number: String,
) -> Option(Int) {
  let key = assert_copy_key(set_code, collector_number, "nonfoil", "en")
  case list.find(rows, fn(row) { row.key == key }) {
    Ok(row) -> Some(row.quantity)
    Error(Nil) -> None
  }
}

pub fn valid_batch_is_upserted_test() {
  let written = ref.new(None)
  let upsert_cards = build_upsert_cards(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.AddCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 4),
        row(set_code: "lea", collector_number: "2", quantity: 1),
      ]),
      upsert_cards,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert quantity_for(rows, "lea", "1") == Some(4)
  assert quantity_for(rows, "lea", "2") == Some(1)
}

pub fn duplicate_keys_within_one_batch_are_summed_test() {
  let written = ref.new(None)
  let upsert_cards = build_upsert_cards(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.AddCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 2),
        row(set_code: "lea", collector_number: "1", quantity: 3),
      ]),
      upsert_cards,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert list.length(rows) == 1
  assert quantity_for(rows, "lea", "1") == Some(5)
}

// Same printing, different language: distinct kinds of copy, not summed.
pub fn different_language_stays_a_separate_row_test() {
  let written = ref.new(None)
  let upsert_cards = build_upsert_cards(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.AddCardsCommand(rows: [
        ports.AddCardsRow(
          set_code: "lea",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity: 2,
        ),
        ports.AddCardsRow(
          set_code: "lea",
          collector_number: "1",
          finish: "nonfoil",
          language: "de",
          quantity: 1,
        ),
      ]),
      upsert_cards,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert list.length(rows) == 2
  let assert Ok(en_row) =
    list.find(rows, fn(row) {
      row.key == assert_copy_key("lea", "1", "nonfoil", "en")
    })
  let assert Ok(de_row) =
    list.find(rows, fn(row) {
      row.key == assert_copy_key("lea", "1", "nonfoil", "de")
    })
  assert en_row.quantity == 2
  assert de_row.quantity == 1
}

pub fn one_invalid_row_rejects_the_whole_batch_test() {
  let written = ref.new(None)
  let upsert_cards = build_upsert_cards(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.AddCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 1),
        row(set_code: "", collector_number: "2", quantity: 1),
      ]),
      upsert_cards,
    )

  assert result == Error(ports.InvalidRows)
  assert ref.get(written) == None
}

pub fn empty_batch_is_rejected_test() {
  let written = ref.new(None)
  let upsert_cards = build_upsert_cards(written:, result: Ok(Nil))

  let result = handler.execute(handler.AddCardsCommand(rows: []), upsert_cards)

  assert result == Error(ports.InvalidRows)
  assert ref.get(written) == None
}

pub fn persistence_failure_reports_error_test() {
  let written = ref.new(None)
  let upsert_cards = build_upsert_cards(written:, result: Error("disk full"))

  let result =
    handler.execute(
      handler.AddCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 1),
      ]),
      upsert_cards,
    )

  assert result == Error(ports.PersistenceFailed("disk full"))
}

import collection/application/commands/import_collection/handler
import collection/application/commands/import_collection/ports
import gleam/list
import gleam/option.{type Option, None, Some}
import shared/domain/card_key
import support/ref

fn build_replace_collection(
  written written: ref.Ref(Option(List(ports.CollectionRowWriteModel))),
  result result: Result(Nil, String),
) -> ports.ReplaceCollectionPort {
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

fn assert_card_key(
  set_code: String,
  collector_number: String,
) -> card_key.CardKey {
  let assert Ok(key) =
    card_key.new(set_code: set_code, collector_number: collector_number)
  key
}

fn quantity_for(
  rows: List(ports.CollectionRowWriteModel),
  set_code: String,
  collector_number: String,
) -> Option(Int) {
  let key = assert_card_key(set_code, collector_number)
  case list.find(rows, fn(row) { row.key == key }) {
    Ok(row) -> Some(row.quantity)
    Error(Nil) -> None
  }
}

pub fn valid_rows_replace_the_collection_test() {
  let written = ref.new(None)
  let replace_collection = build_replace_collection(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(rows: [
        ports.ImportCollectionRow(
          set_code: "lea",
          collector_number: "1",
          quantity: 4,
        ),
        ports.ImportCollectionRow(
          set_code: "lea",
          collector_number: "2",
          quantity: 1,
        ),
      ]),
      replace_collection,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert quantity_for(rows, "lea", "1") == Some(4)
  assert quantity_for(rows, "lea", "2") == Some(1)
}

pub fn duplicate_keys_within_one_import_are_summed_test() {
  let written = ref.new(None)
  let replace_collection = build_replace_collection(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(rows: [
        ports.ImportCollectionRow(
          set_code: "lea",
          collector_number: "1",
          quantity: 2,
        ),
        ports.ImportCollectionRow(
          set_code: "lea",
          collector_number: "1",
          quantity: 3,
        ),
      ]),
      replace_collection,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert list.length(rows) == 1
  assert quantity_for(rows, "lea", "1") == Some(5)
}

pub fn one_invalid_row_rejects_the_whole_import_test() {
  let written = ref.new(None)
  let replace_collection = build_replace_collection(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(rows: [
        ports.ImportCollectionRow(
          set_code: "lea",
          collector_number: "1",
          quantity: 2,
        ),
        ports.ImportCollectionRow(
          set_code: "",
          collector_number: "2",
          quantity: 1,
        ),
      ]),
      replace_collection,
    )

  assert result == Error(ports.InvalidRows)
  assert ref.get(written) == None
}

pub fn empty_import_is_rejected_test() {
  let written = ref.new(None)
  let replace_collection = build_replace_collection(written:, result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(rows: []),
      replace_collection,
    )

  assert result == Error(ports.InvalidRows)
  assert ref.get(written) == None
}

pub fn persistence_failure_reports_error_test() {
  let written = ref.new(None)
  let replace_collection =
    build_replace_collection(written:, result: Error("disk full"))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(rows: [
        ports.ImportCollectionRow(
          set_code: "lea",
          collector_number: "1",
          quantity: 1,
        ),
      ]),
      replace_collection,
    )

  assert result == Error(ports.PersistenceFailed("disk full"))
}

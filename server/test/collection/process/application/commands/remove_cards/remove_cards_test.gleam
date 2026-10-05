import collection/application/commands/remove_cards/handler
import collection/application/commands/remove_cards/ports
import gleam/list
import gleam/option.{type Option, None, Some}
import shared/domain/copy_key
import support/ref

fn build_ports(
  written written: ref.Ref(Option(List(ports.CollectionRowWriteModel))),
  notified notified: ref.Ref(Bool),
  result result: Result(Nil, String),
  owned owned: Int,
) -> ports.RemoveCardsPorts {
  ports.RemoveCardsPorts(
    owned_quantity: fn(_) { Ok(owned) },
    decrement_cards: fn(rows) {
      case result {
        Ok(Nil) -> {
          ref.set(written, Some(rows))
          Ok(Nil)
        }
        Error(reason) -> Error(reason)
      }
    },
    notify_changed: fn(_) {
      ref.set(notified, True)
      Ok(Nil)
    },
  )
}

fn row(
  set_code set_code: String,
  collector_number collector_number: String,
  quantity quantity: Int,
) -> ports.RemoveCardsRow {
  ports.RemoveCardsRow(
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

pub fn valid_batch_is_decremented_and_notifies_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 10)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 2),
      ]),
      command_ports,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert quantity_for(rows, "lea", "1") == Some(2)
  assert ref.get(notified) == True
}

pub fn duplicate_keys_within_one_batch_are_summed_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 10)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 2),
        row(set_code: "lea", collector_number: "1", quantity: 3),
      ]),
      command_ports,
    )

  assert result == Ok(Nil)

  let assert Some(rows) = ref.get(written)
  assert list.length(rows) == 1
  assert quantity_for(rows, "lea", "1") == Some(5)
}

pub fn one_invalid_row_rejects_the_whole_batch_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 10)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 1),
        row(set_code: "", collector_number: "2", quantity: 1),
      ]),
      command_ports,
    )

  assert result == Error(ports.InvalidRows)
  assert ref.get(written) == None
  assert ref.get(notified) == False
}

pub fn empty_batch_is_rejected_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 10)

  let result =
    handler.execute(handler.RemoveCardsCommand(rows: []), command_ports)

  assert result == Error(ports.InvalidRows)
  assert ref.get(written) == None
  assert ref.get(notified) == False
}

pub fn persistence_failure_reports_error_and_does_not_notify_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Error("disk full"), owned: 10)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 1),
      ]),
      command_ports,
    )

  assert result == Error(ports.PersistenceFailed("disk full"))
  assert ref.get(notified) == False
}

pub fn removal_exceeding_the_owned_quantity_rejects_the_batch_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 1)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 2),
      ]),
      command_ports,
    )

  assert result == Error(ports.ExceedsOwned)
  assert ref.get(written) == None
  assert ref.get(notified) == False
}

pub fn removing_an_unowned_key_is_rejected_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 0)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "999", quantity: 1),
      ]),
      command_ports,
    )

  assert result == Error(ports.ExceedsOwned)
  assert ref.get(written) == None
}

pub fn removing_exactly_the_owned_quantity_is_allowed_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 3)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 3),
      ]),
      command_ports,
    )

  assert result == Ok(Nil)
}

// The cap applies to the merged quantity, not each row on its own.
pub fn duplicate_rows_are_checked_against_their_sum_test() {
  let written = ref.new(None)
  let notified = ref.new(False)
  let command_ports =
    build_ports(written:, notified:, result: Ok(Nil), owned: 4)

  let result =
    handler.execute(
      handler.RemoveCardsCommand(rows: [
        row(set_code: "lea", collector_number: "1", quantity: 2),
        row(set_code: "lea", collector_number: "1", quantity: 3),
      ]),
      command_ports,
    )

  assert result == Error(ports.ExceedsOwned)
}

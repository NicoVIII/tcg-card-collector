import collection/application/commands/add_cards/ports as add_cards_ports
import collection/domain/collection
import collection/domain/import_status
import collection/domain/physical_card
import gleam/list
import gleam/result
import shared/application/command_result
import shared/domain/card_key
import shared/domain/non_empty_string.{type NonEmptyString}

/// Manual adds are persisted as import runs; the source name is fixed here
/// so both transports (skir + http) record identical runs.
const manual_add_source_name = "manual-add"

pub type AddCardsCommand {
  AddCardsCommand(
    add_run_id: NonEmptyString,
    rows: List(add_cards_ports.AddCardsRow),
  )
}

fn record_run(
  ports: add_cards_ports.AddCardsPorts,
  id: String,
  status: import_status.ImportStatus,
  row_count: Int,
) -> Result(Nil, String) {
  ports.save_run(add_cards_ports.AddRunWriteModel(
    id: id,
    source_name: manual_add_source_name,
    status: status,
    row_count: row_count,
  ))
}

/// All-or-nothing: the client stages pre-validated entries, so a single
/// invalid row means a client bug — partial acceptance would only hide it.
/// An empty batch is invalid too; there is nothing to add.
fn validate_rows(
  rows: List(add_cards_ports.AddCardsRow),
) -> Result(List(physical_card.PhysicalCard), Nil) {
  case rows {
    [] -> Error(Nil)
    _ ->
      list.try_map(rows, fn(row) {
        case
          card_key.from_user_input(
            set_code: row.set_code,
            collector_number: row.collector_number,
          ),
          physical_card.quantity_new(row.quantity)
        {
          Ok(key), Ok(quantity) ->
            Ok(physical_card.PhysicalCard(key: key, quantity: quantity))
          _, _ -> Error(Nil)
        }
      })
  }
}

/// Converts previously persisted snapshot rows into a Collection. Previous
/// rows are trusted state, but their quantity still has to pass through
/// quantity_new so a corrupted row surfaces as an error instead of crashing.
fn build_previous_collection(
  rows: List(add_cards_ports.LatestSnapshotRow),
) -> Result(collection.Collection, String) {
  rows
  |> list.try_map(fn(row) {
    physical_card.quantity_new(row.quantity)
    |> result.map(fn(quantity) {
      physical_card.PhysicalCard(key: row.key, quantity: quantity)
    })
    |> result.map_error(fn(_) { "invalid persisted quantity" })
  })
  |> result.map(collection.from_trusted_cards)
}

fn snapshot_row_from_card(
  card: physical_card.PhysicalCard,
) -> add_cards_ports.SnapshotRowWriteModel {
  add_cards_ports.SnapshotRowWriteModel(
    key: card.key,
    quantity: physical_card.quantity_to_int(card.quantity),
  )
}

fn build_merged_rows(
  ports: add_cards_ports.AddCardsPorts,
  added_cards: List(physical_card.PhysicalCard),
) -> Result(List(add_cards_ports.SnapshotRowWriteModel), String) {
  use previous_rows <- result.try(ports.latest_snapshot_rows())
  use previous <- result.map(build_previous_collection(previous_rows))
  collection.merge(previous, collection.from_trusted_cards(added_cards))
  |> collection.to_cards
  |> list.map(snapshot_row_from_card)
}

fn persist_rows(
  ports: add_cards_ports.AddCardsPorts,
  add_run_id: String,
  added_row_count: Int,
  rows: List(add_cards_ports.SnapshotRowWriteModel),
) -> command_result.CommandResult(add_cards_ports.AddCardsError) {
  case ports.replace_rows(add_run_id, rows) {
    Ok(Nil) ->
      case
        record_run(ports, add_run_id, import_status.Succeeded, added_row_count)
      {
        Ok(Nil) -> Ok(Nil)
        Error(reason) -> Error(add_cards_ports.PersistenceFailed(reason))
      }
    Error(reason) -> {
      let _ =
        record_run(ports, add_run_id, import_status.Failed, added_row_count)
      Error(add_cards_ports.PersistenceFailed(reason))
    }
  }
}

/// Read-merge-write without a transaction: a concurrent add or import can
/// lose this update (last write wins). Acceptable for a single-user app.
pub fn execute(
  command: AddCardsCommand,
  ports: add_cards_ports.AddCardsPorts,
) -> command_result.CommandResult(add_cards_ports.AddCardsError) {
  let AddCardsCommand(add_run_id: add_run_id_nes, rows: rows) = command
  let add_run_id = non_empty_string.to_string(add_run_id_nes)
  // The run records how many rows were added, not the merged snapshot size —
  // that is what the status line should report about this operation.
  let added_row_count = list.length(rows)

  case validate_rows(rows) {
    Error(Nil) -> {
      let _ =
        record_run(ports, add_run_id, import_status.Failed, added_row_count)
      Error(add_cards_ports.InvalidRows)
    }
    Ok(added_cards) -> {
      // Best-effort progress marker; also creates the run row the snapshot's
      // foreign key needs before replace_rows inserts against it.
      let _ =
        record_run(ports, add_run_id, import_status.Running, added_row_count)
      case build_merged_rows(ports, added_cards) {
        Ok(merged_rows) ->
          persist_rows(ports, add_run_id, added_row_count, merged_rows)
        Error(reason) -> {
          let _ =
            record_run(ports, add_run_id, import_status.Failed, added_row_count)
          Error(add_cards_ports.PersistenceFailed(reason))
        }
      }
    }
  }
}

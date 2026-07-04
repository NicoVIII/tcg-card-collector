import collection/application/commands/import_collection/ports as import_collection_ports
import collection/domain/collection
import collection/domain/import_mode.{type ImportMode}
import collection/domain/import_status
import collection/domain/physical_card
import gleam/list
import gleam/result
import shared/application/command_result
import shared/domain/card_key
import shared/domain/non_empty_string.{type NonEmptyString}

pub type ImportCollectionCommand {
  ImportCollectionCommand(
    import_run_id: NonEmptyString,
    source_name: NonEmptyString,
    row_count: Int,
    rows: List(import_collection_ports.ImportCollectionRow),
    mode: ImportMode,
  )
}

pub fn execute(
  command: ImportCollectionCommand,
  ports: import_collection_ports.ImportCollectionPorts,
) -> command_result.CommandResult(import_collection_ports.ImportCollectionError) {
  let ImportCollectionCommand(
    import_run_id: import_run_id_nes,
    source_name: source_name_nes,
    row_count: row_count,
    rows: rows,
    mode: mode,
  ) = command

  let import_run_id = non_empty_string.to_string(import_run_id_nes)
  let source_name = non_empty_string.to_string(source_name_nes)

  let actual_row_count = list.length(rows)

  // Best-effort progress marker: a failure to record it doesn't block the
  // import, it only means the intermediate status isn't observable.
  let _ =
    record_run(
      ports,
      import_run_id,
      source_name,
      import_status.Running,
      actual_row_count,
      mode,
    )

  // Build owned cards; rows with a blank set_code/collector_number or a
  // non-positive quantity are dropped, which triggers RowCountMismatch below.
  let valid_cards =
    list.filter_map(rows, fn(row) {
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

  case collection.from_cards(valid_cards, row_count) {
    Ok(coll) ->
      apply_snapshot(
        ports,
        import_run_id,
        source_name,
        actual_row_count,
        mode,
        coll,
      )
    Error(collection.RowCountMismatch) -> {
      let _ =
        record_run(
          ports,
          import_run_id,
          source_name,
          import_status.Failed,
          actual_row_count,
          mode,
        )
      Error(import_collection_ports.RowCountMismatch)
    }
  }
}

fn apply_snapshot(
  ports: import_collection_ports.ImportCollectionPorts,
  import_run_id: String,
  source_name: String,
  actual_row_count: Int,
  mode: ImportMode,
  coll: collection.Collection,
) -> command_result.CommandResult(import_collection_ports.ImportCollectionError) {
  case mode {
    import_mode.Full ->
      persist_rows(
        ports,
        import_run_id,
        source_name,
        actual_row_count,
        mode,
        list.map(collection.to_cards(coll), snapshot_row_from_card),
      )
    import_mode.Delta ->
      case ports.latest_snapshot_rows() {
        Ok(previous) ->
          case build_previous_collection(previous) {
            Ok(previous_coll) ->
              persist_rows(
                ports,
                import_run_id,
                source_name,
                actual_row_count,
                mode,
                list.map(
                  collection.to_cards(collection.merge(previous_coll, coll)),
                  snapshot_row_from_card,
                ),
              )
            Error(reason) -> {
              let _ =
                record_run(
                  ports,
                  import_run_id,
                  source_name,
                  import_status.Failed,
                  actual_row_count,
                  mode,
                )
              Error(import_collection_ports.PersistenceFailed(reason))
            }
          }
        Error(reason) -> {
          let _ =
            record_run(
              ports,
              import_run_id,
              source_name,
              import_status.Failed,
              actual_row_count,
              mode,
            )
          Error(import_collection_ports.PersistenceFailed(reason))
        }
      }
  }
}

fn persist_rows(
  ports: import_collection_ports.ImportCollectionPorts,
  import_run_id: String,
  source_name: String,
  actual_row_count: Int,
  mode: ImportMode,
  rows: List(import_collection_ports.SnapshotRowWriteModel),
) -> command_result.CommandResult(import_collection_ports.ImportCollectionError) {
  case ports.replace_rows(import_run_id, rows) {
    Ok(Nil) ->
      case
        record_run(
          ports,
          import_run_id,
          source_name,
          import_status.Succeeded,
          actual_row_count,
          mode,
        )
      {
        Ok(Nil) -> Ok(Nil)
        Error(reason) ->
          Error(import_collection_ports.PersistenceFailed(reason))
      }
    Error(reason) -> {
      let _ =
        record_run(
          ports,
          import_run_id,
          source_name,
          import_status.Failed,
          actual_row_count,
          mode,
        )
      Error(import_collection_ports.PersistenceFailed(reason))
    }
  }
}

fn snapshot_row_from_card(
  card: physical_card.PhysicalCard,
) -> import_collection_ports.SnapshotRowWriteModel {
  import_collection_ports.SnapshotRowWriteModel(
    key: card.key,
    quantity: physical_card.quantity_to_int(card.quantity),
  )
}

/// Converts previously persisted snapshot rows into a Collection. Previous
/// rows are trusted state, but their quantity still has to pass through
/// quantity_new so a corrupted row surfaces as an error instead of crashing.
fn build_previous_collection(
  rows: List(import_collection_ports.LatestSnapshotRow),
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

fn record_run(
  ports: import_collection_ports.ImportCollectionPorts,
  id: String,
  source_name: String,
  status: import_status.ImportStatus,
  row_count: Int,
  mode: ImportMode,
) -> Result(Nil, String) {
  ports.save_run(import_collection_ports.ImportRunWriteModel(
    id: id,
    source_name: source_name,
    status: status,
    row_count: row_count,
    mode: mode,
  ))
}

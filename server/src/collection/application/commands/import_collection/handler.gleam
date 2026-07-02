import collection/application/commands/import_collection/ports as import_collection_ports
import collection/domain/collection
import collection/domain/import_status
import collection/domain/physical_card
import gleam/list
import shared/application/command_result
import shared/domain/card_key

pub type ImportCollectionCommand {
  ImportCollectionCommand(
    import_run_id: String,
    source_name: String,
    source_checksum: String,
    row_count: Int,
    rows: List(import_collection_ports.ImportCollectionRow),
  )
}

pub fn execute(
  command: ImportCollectionCommand,
  ports: import_collection_ports.ImportCollectionPorts,
) -> command_result.CommandResult(import_collection_ports.ImportCollectionError) {
  let ImportCollectionCommand(
    import_run_id: import_run_id,
    source_name: source_name,
    row_count: row_count,
    rows: rows,
    ..,
  ) = command

  let actual_row_count = list.length(rows)

  // Progress markers are best-effort: a failure to record them doesn't block
  // the import, it only means the intermediate status isn't observable.
  let _ =
    record_run(
      ports,
      import_run_id,
      source_name,
      import_status.Pending,
      actual_row_count,
    )
  let _ =
    record_run(
      ports,
      import_run_id,
      source_name,
      import_status.Running,
      actual_row_count,
    )

  // Build owned cards; rows with blank set_code/collector_number are dropped,
  // which triggers RowCountMismatch below.
  let valid_cards =
    list.filter_map(rows, fn(row) {
      case
        card_key.from_user_input(
          set_code: row.set_code,
          collector_number: row.collector_number,
        )
      {
        Error(_) -> Error(Nil)
        Ok(key) ->
          Ok(physical_card.PhysicalCard(key: key, quantity: row.quantity))
      }
    })

  case collection.from_cards(valid_cards, row_count) {
    Ok(coll) ->
      case
        ports.replace_rows(
          import_run_id,
          list.map(coll.cards, fn(card) {
            import_collection_ports.SnapshotRowWriteModel(
              key: card.key,
              quantity: card.quantity,
            )
          }),
        )
      {
        Ok(Nil) ->
          case
            record_run(
              ports,
              import_run_id,
              source_name,
              import_status.Succeeded,
              actual_row_count,
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
            )
          Error(import_collection_ports.PersistenceFailed(reason))
        }
      }
    Error(collection.RowCountMismatch) -> {
      let _ =
        record_run(
          ports,
          import_run_id,
          source_name,
          import_status.Failed,
          actual_row_count,
        )
      Error(import_collection_ports.RowCountMismatch)
    }
  }
}

fn record_run(
  ports: import_collection_ports.ImportCollectionPorts,
  id: String,
  source_name: String,
  status: import_status.ImportStatus,
  row_count: Int,
) -> Result(Nil, String) {
  ports.save_run(import_collection_ports.ImportRunWriteModel(
    id: id,
    source_name: source_name,
    status: status,
    row_count: row_count,
  ))
}

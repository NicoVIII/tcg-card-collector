import application/commands/collection_import/import_collection/ports
import application/commands/command_result
import gleam/list

pub type ImportCollectionCommand {
  ImportCollectionCommand(
    import_run_id: String,
    source_name: String,
    source_checksum: String,
    row_count: Int,
    rows: List(ports.ImportCollectionRow),
  )
}

pub fn execute(
  command: ImportCollectionCommand,
  port: ports.ImportCollectionPort,
) -> command_result.CommandResult(ports.ImportCollectionError) {
  let ImportCollectionCommand(
    import_run_id: import_run_id,
    source_name: source_name,
    row_count: row_count,
    rows: rows,
    ..,
  ) = command

  let actual_row_count = list.length(rows)

  save_run(port, import_run_id, source_name, "pending", actual_row_count)
  save_run(port, import_run_id, source_name, "running", actual_row_count)

  case row_count == actual_row_count {
    True -> {
      port.replace_rows(
        import_run_id,
        list.map(rows, fn(row) {
          let ports.ImportCollectionRow(
            card_name: card_name,
            set_code: set_code,
            collector_number: collector_number,
            quantity: quantity,
          ) = row
          ports.SnapshotRowWriteModel(
            card_name: card_name,
            set_code: set_code,
            collector_number: collector_number,
            quantity: quantity,
          )
        }),
      )
      save_run(port, import_run_id, source_name, "succeeded", actual_row_count)
      Ok(Nil)
    }
    False -> {
      save_run(port, import_run_id, source_name, "failed", actual_row_count)
      Error(ports.RowCountMismatch)
    }
  }
}

fn save_run(
  port: ports.ImportCollectionPort,
  id: String,
  source_name: String,
  status: String,
  row_count: Int,
) -> Nil {
  port.save_run(ports.ImportRunWriteModel(
    id: id,
    source_name: source_name,
    status: status,
    row_count: row_count,
  ))
}

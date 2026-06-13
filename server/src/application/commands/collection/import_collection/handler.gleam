import application/commands/collection/import_collection/ports
import application/commands/command_result
import common/card_key
import domain/collection/collection
import domain/collection/import_status
import domain/collection/physical_card
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

  record_run(
    port,
    import_run_id,
    source_name,
    import_status.Pending,
    actual_row_count,
  )
  record_run(
    port,
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
        card_key.new(
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
    Ok(coll) -> {
      port.replace_rows(
        import_run_id,
        list.map(coll.cards, fn(card) {
          ports.SnapshotRowWriteModel(key: card.key, quantity: card.quantity)
        }),
      )
      record_run(
        port,
        import_run_id,
        source_name,
        import_status.Succeeded,
        actual_row_count,
      )
      Ok(Nil)
    }
    Error(collection.RowCountMismatch) -> {
      record_run(
        port,
        import_run_id,
        source_name,
        import_status.Failed,
        actual_row_count,
      )
      Error(ports.RowCountMismatch)
    }
  }
}

fn record_run(
  port: ports.ImportCollectionPort,
  id: String,
  source_name: String,
  status: import_status.ImportStatus,
  row_count: Int,
) -> Nil {
  port.save_run(ports.ImportRunWriteModel(
    id: id,
    source_name: source_name,
    status: status,
    row_count: row_count,
  ))
}

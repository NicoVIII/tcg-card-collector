import collection/application/commands/import_collection/ports
import collection/infrastructure/stores/collection_store
import common/non_empty_string
import gleam/list

pub fn new() -> ports.ImportCollectionPorts {
  ports.ImportCollectionPorts(
    save_run: save_run_adapter(),
    replace_rows: replace_rows_adapter(),
  )
}

fn save_run_adapter() -> ports.SaveRunPort {
  fn(run) {
    let ports.ImportRunWriteModel(
      id: id,
      source_name: source_name,
      status: status,
      row_count: row_count,
    ) = run
    collection_store.save(id, source_name, status, row_count)
  }
}

fn replace_rows_adapter() -> ports.ReplaceRowsPort {
  fn(import_run_id, rows) {
    collection_store.replace_rows(
      import_run_id,
      list.map(rows, fn(row) {
        let ports.SnapshotRowWriteModel(key: key, quantity: quantity) = row
        #(
          non_empty_string.to_string(key.set_code),
          non_empty_string.to_string(key.collector_number),
          quantity,
        )
      }),
    )
  }
}

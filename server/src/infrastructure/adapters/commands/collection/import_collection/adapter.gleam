import application/commands/collection/import_collection/ports
import common/non_empty_string
import gleam/list
import infrastructure/stores/collection/collection_store

pub fn new() -> ports.ImportCollectionPort {
  ports.ImportCollectionPort(
    save_run: fn(run) {
      let ports.ImportRunWriteModel(
        id: id,
        source_name: source_name,
        status: status,
        row_count: row_count,
      ) = run
      collection_store.save(id, source_name, status, row_count)
    },
    replace_rows: fn(import_run_id, rows) {
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
    },
  )
}

import application/commands/collection_import/import_collection/ports
import gleam/list
import infrastructure/stores/collection_import/collection_import_store

pub fn new() -> ports.ImportCollectionPort {
  ports.ImportCollectionPort(
    save_run: fn(run) {
      let ports.ImportRunWriteModel(
        id: id,
        source_name: source_name,
        status: status,
        row_count: row_count,
      ) = run
      collection_import_store.save(id, source_name, status, row_count)
    },
    replace_rows: fn(import_run_id, rows) {
      collection_import_store.replace_rows(
        import_run_id,
        rows
          |> list.map(fn(row) {
            let ports.SnapshotRowWriteModel(
              card_name: card_name,
              set_code: set_code,
              collector_number: collector_number,
              quantity: quantity,
            ) = row
            #(card_name, set_code, collector_number, quantity)
          }),
      )
    },
  )
}

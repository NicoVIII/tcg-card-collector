import collection/application/commands/import_collection/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result
import shared/domain/card_key
import shared/domain/non_empty_string

pub fn new() -> ports.ImportCollectionPorts {
  ports.ImportCollectionPorts(
    save_run: save_run_adapter(),
    replace_rows: replace_rows_adapter(),
    latest_snapshot_rows: latest_snapshot_rows_adapter(),
  )
}

fn save_run_adapter() -> ports.SaveRunPort {
  fn(run) {
    let ports.ImportRunWriteModel(
      id: id,
      source_name: source_name,
      status: status,
      row_count: row_count,
      mode: mode,
    ) = run
    collection_dao.save(id, source_name, status, row_count, mode)
  }
}

fn replace_rows_adapter() -> ports.ReplaceRowsPort {
  fn(import_run_id, rows) {
    collection_dao.replace_rows(
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

fn latest_snapshot_rows_adapter() -> ports.LatestSnapshotRowsPort {
  fn() {
    use rows <- result.try(collection_dao.latest_snapshot_rows())
    rows
    |> list.try_map(fn(row) {
      let #(set_code, collector_number, quantity) = row
      card_key.new(set_code: set_code, collector_number: collector_number)
      |> result.map(fn(key) {
        ports.LatestSnapshotRow(key: key, quantity: quantity)
      })
      |> result.map_error(fn(_) { "invalid persisted card key" })
    })
  }
}

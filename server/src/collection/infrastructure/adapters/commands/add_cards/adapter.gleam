import collection/application/commands/add_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result
import shared/domain/card_key

fn save_run_adapter() -> ports.SaveRunPort {
  fn(run) {
    let ports.AddRunWriteModel(
      id: id,
      source_name: source_name,
      status: status,
      row_count: row_count,
    ) = run
    collection_dao.save(id, source_name, status, row_count)
  }
}

fn replace_rows_adapter() -> ports.ReplaceRowsPort {
  fn(add_run_id, rows) {
    collection_dao.replace_rows(
      add_run_id,
      list.map(rows, fn(row) {
        let ports.SnapshotRowWriteModel(key: key, quantity: quantity) = row
        #(
          card_key.set_code_string(key),
          card_key.collector_number_string(key),
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

pub fn new() -> ports.AddCardsPorts {
  ports.AddCardsPorts(
    save_run: save_run_adapter(),
    replace_rows: replace_rows_adapter(),
    latest_snapshot_rows: latest_snapshot_rows_adapter(),
  )
}

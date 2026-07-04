import collection/domain/import_mode.{type ImportMode}
import collection/domain/import_status.{type ImportStatus}
import shared/domain/card_key.{type CardKey}

pub type ImportCollectionRow {
  ImportCollectionRow(set_code: String, collector_number: String, quantity: Int)
}

pub type ImportRunWriteModel {
  ImportRunWriteModel(
    id: String,
    source_name: String,
    status: ImportStatus,
    row_count: Int,
    mode: ImportMode,
  )
}

pub type SnapshotRowWriteModel {
  SnapshotRowWriteModel(key: CardKey, quantity: Int)
}

pub type LatestSnapshotRow {
  LatestSnapshotRow(key: CardKey, quantity: Int)
}

pub type SaveRunPort =
  fn(ImportRunWriteModel) -> Result(Nil, String)

pub type ReplaceRowsPort =
  fn(String, List(SnapshotRowWriteModel)) -> Result(Nil, String)

pub type LatestSnapshotRowsPort =
  fn() -> Result(List(LatestSnapshotRow), String)

pub type ImportCollectionPorts {
  ImportCollectionPorts(
    save_run: SaveRunPort,
    replace_rows: ReplaceRowsPort,
    latest_snapshot_rows: LatestSnapshotRowsPort,
  )
}

pub type ImportCollectionError {
  RowCountMismatch
  PersistenceFailed(reason: String)
}

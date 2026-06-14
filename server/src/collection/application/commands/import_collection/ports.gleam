import collection/domain/import_status.{type ImportStatus}
import common/card_key.{type CardKey}

pub type ImportCollectionRow {
  ImportCollectionRow(set_code: String, collector_number: String, quantity: Int)
}

pub type ImportRunWriteModel {
  ImportRunWriteModel(
    id: String,
    source_name: String,
    status: ImportStatus,
    row_count: Int,
  )
}

pub type SnapshotRowWriteModel {
  SnapshotRowWriteModel(key: CardKey, quantity: Int)
}

pub type ImportCollectionPort {
  ImportCollectionPort(
    save_run: fn(ImportRunWriteModel) -> Nil,
    replace_rows: fn(String, List(SnapshotRowWriteModel)) -> Nil,
  )
}

pub type ImportCollectionError {
  RowCountMismatch
}

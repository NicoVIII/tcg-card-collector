pub type ImportCollectionRow {
  ImportCollectionRow(
    card_name: String,
    set_code: String,
    collector_number: String,
    quantity: Int,
  )
}

pub type ImportRunWriteModel {
  ImportRunWriteModel(
    id: String,
    source_name: String,
    status: String,
    row_count: Int,
  )
}

pub type SnapshotRowWriteModel {
  SnapshotRowWriteModel(
    card_name: String,
    set_code: String,
    collector_number: String,
    quantity: Int,
  )
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

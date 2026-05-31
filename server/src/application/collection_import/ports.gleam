import gleam/option.{type Option}

pub type ImportRunWriteModel {
  ImportRunWriteModel(
    id: String,
    source_name: String,
    status: String,
    row_count: Int,
  )
}

pub type ImportRunReadModel {
  ImportRunReadModel(
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

pub type CollectionImportRepository {
  CollectionImportRepository(
    save_import_run: fn(ImportRunWriteModel) -> Nil,
    replace_snapshot_rows: fn(String, List(SnapshotRowWriteModel)) -> Nil,
    latest_import_run: fn() -> Option(ImportRunReadModel),
  )
}

pub fn save(
  repository: CollectionImportRepository,
  run: ImportRunWriteModel,
) -> Nil {
  let CollectionImportRepository(save_import_run: save_import_run, ..) =
    repository
  save_import_run(run)
}

pub fn replace_rows(
  repository: CollectionImportRepository,
  import_run_id: String,
  rows: List(SnapshotRowWriteModel),
) -> Nil {
  let CollectionImportRepository(
    replace_snapshot_rows: replace_snapshot_rows,
    ..,
  ) = repository
  replace_snapshot_rows(import_run_id, rows)
}

pub fn latest(
  repository: CollectionImportRepository,
) -> Option(ImportRunReadModel) {
  let CollectionImportRepository(latest_import_run: latest_import_run, ..) =
    repository
  latest_import_run()
}

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

pub type CollectionImportRepository {
  CollectionImportRepository(
    save_import_run: fn(ImportRunWriteModel) -> Nil,
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

pub fn latest(
  repository: CollectionImportRepository,
) -> Option(ImportRunReadModel) {
  let CollectionImportRepository(latest_import_run: latest_import_run, ..) =
    repository
  latest_import_run()
}

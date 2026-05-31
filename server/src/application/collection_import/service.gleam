import application/collection_import/ports
import gleam/option.{type Option}

pub fn import_collection(
  repository: ports.CollectionImportRepository,
  run: ports.ImportRunWriteModel,
) -> Nil {
  ports.save(repository, run)
}

pub fn replace_snapshot_rows(
  repository: ports.CollectionImportRepository,
  import_run_id: String,
  rows: List(ports.SnapshotRowWriteModel),
) -> Nil {
  ports.replace_rows(repository, import_run_id, rows)
}

pub fn latest_import_status(
  repository: ports.CollectionImportRepository,
) -> Option(ports.ImportRunReadModel) {
  ports.latest(repository)
}

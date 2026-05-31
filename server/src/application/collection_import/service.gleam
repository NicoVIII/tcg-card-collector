import application/collection_import/ports
import gleam/option.{type Option}

pub fn import_collection(
  repository: ports.CollectionImportRepository,
  run: ports.ImportRunWriteModel,
) -> Nil {
  ports.save(repository, run)
}

pub fn latest_import_status(
  repository: ports.CollectionImportRepository,
) -> Option(ports.ImportRunReadModel) {
  ports.latest(repository)
}

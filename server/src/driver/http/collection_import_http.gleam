import application/collection_import/ports
import driver/skir/collection_import_handler

pub fn import_collection(
  repository: ports.CollectionImportRepository,
  request: collection_import_handler.ImportCollectionRequest,
) -> collection_import_handler.ImportCollectionResponse {
  collection_import_handler.import_collection(repository, request)
}

pub fn latest_import_status(
  repository: ports.CollectionImportRepository,
) -> collection_import_handler.LatestImportStatusResponse {
  collection_import_handler.get_latest_import_status(repository)
}

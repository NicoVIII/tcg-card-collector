import portability/domain/export_document.{type CollectionEntry}

pub type ReplaceCollectionPort =
  fn(List(CollectionEntry)) -> Result(Nil, String)

pub type ImportDataPorts {
  ImportDataPorts(replace_collection: ReplaceCollectionPort)
}

pub type ImportDataError {
  NothingToImport
  PersistenceFailed(reason: String)
}

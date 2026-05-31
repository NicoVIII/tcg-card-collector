pub type CollectionImportTerm {
  ImportRun
  CollectionSnapshot
  ImportSource
  ImportStatus
}

pub fn bounded_context_name() -> String {
  "collection_import"
}

pub fn ubiquitous_language() -> List(String) {
  ["ImportRun", "CollectionSnapshot", "ImportSource", "ImportStatus"]
}

import gleam/string

pub opaque type ImportSource {
  ImportSource(file_name: String)
}

pub type ImportSourceError {
  EmptyImportSourceFileName
}

pub fn new(file_name: String) -> Result(ImportSource, ImportSourceError) {
  case string.length(file_name) == 0 {
    True -> Error(EmptyImportSourceFileName)
    False -> Ok(ImportSource(file_name))
  }
}

pub fn file_name(import_source: ImportSource) -> String {
  let ImportSource(file_name) = import_source
  file_name
}

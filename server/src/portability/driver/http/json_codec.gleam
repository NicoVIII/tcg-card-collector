import gleam/json
import gleam/list
import portability/domain/import_document.{
  type ImportDocument, type RejectedEntry,
}

pub fn encode_import_preview(document: ImportDocument) -> String {
  json.object([
    #("entry_count", json.int(list.length(document.collection))),
    #("rejected", json.array(document.rejected, of: encode_rejected_entry)),
  ])
  |> json.to_string
}

pub fn encode_imported_data(entry_count: Int) -> String {
  json.object([#("entry_count", json.int(entry_count))])
  |> json.to_string
}

fn encode_rejected_entry(rejected: RejectedEntry) -> json.Json {
  json.object([
    #("position", json.int(rejected.position)),
    #("identity", json.string(rejected.identity)),
    #("reason", json.string(rejected.reason)),
  ])
}

import gleam/json
import portability/domain/import_document.{
  type ImportDocument, type RejectedEntry, type SectionResult,
}

pub fn encode_import_preview(document: ImportDocument) -> String {
  json.object([
    #(
      "sections",
      json.array(
        import_document.section_results(document),
        of: encode_section_result,
      ),
    ),
    #("rejected", json.array(document.rejected, of: encode_rejected_entry)),
  ])
  |> json.to_string
}

pub fn encode_imported_data(sections: List(SectionResult)) -> String {
  json.object([#("sections", json.array(sections, of: encode_section_result))])
  |> json.to_string
}

fn encode_section_result(result: SectionResult) -> json.Json {
  json.object([
    #("section", json.string(import_document.section_name(result.section))),
    #("count", json.int(result.count)),
  ])
}

fn encode_rejected_entry(rejected: RejectedEntry) -> json.Json {
  json.object([
    #("section", json.string(import_document.section_name(rejected.section))),
    #("position", json.int(rejected.position)),
    #("identity", json.string(rejected.identity)),
    #("reason", json.string(rejected.reason)),
  ])
}

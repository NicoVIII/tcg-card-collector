import gleam/json
import portability/application/queries/preview_import/handler.{
  type ImportPreview,
}
import portability/domain/import_document.{
  type LedgerExcess, type RejectedEntry, type SectionResult,
}

pub fn encode_import_preview(preview: ImportPreview) -> String {
  json.object([
    #("sections", json.array(preview.sections, of: encode_section_result)),
    #("rejected", json.array(preview.rejected, of: encode_rejected_entry)),
    #("excess", json.array(preview.excess, of: encode_ledger_excess)),
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

fn encode_ledger_excess(excess: LedgerExcess) -> json.Json {
  json.object([
    #("identity", json.string(excess.identity)),
    #("placed", json.int(excess.placed)),
    #("owned", json.int(excess.owned)),
  ])
}

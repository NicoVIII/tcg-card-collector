import gleam/json
import portability/application/commands/import_data/handler.{type ImportResult} as _
import portability/application/queries/preview_import/handler.{
  type ImportPreview,
}
import portability/domain/export_document.{
  type PlacedIn, InLocation, InManagedLocation,
}
import portability/domain/import_document.{
  type LedgerPrune, type ManagedShortfall, type RejectedEntry,
  type SectionResult,
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

fn encode_managed_shortfall(shortfall: ManagedShortfall) -> json.Json {
  json.object([
    #("location_name", json.string(shortfall.location_name)),
    #("identity", json.string(shortfall.identity)),
    #("missing", json.int(shortfall.missing)),
  ])
}

// REST's twin of the skir PlacedIn union: `{"kind": "cascade" | "managed",
// "name": <name>}`, the shape Inventory Planning's LocationRef uses.
fn encode_placed_in(location: PlacedIn) -> json.Json {
  let #(kind, name) = case location {
    InLocation(name) -> #("cascade", name)
    InManagedLocation(name) -> #("managed", name)
  }
  json.object([#("kind", json.string(kind)), #("name", json.string(name))])
}

fn encode_ledger_prune(prune: LedgerPrune) -> json.Json {
  json.object([
    #("identity", json.string(prune.identity)),
    #("location", encode_placed_in(prune.location)),
    #("quantity", json.int(prune.quantity)),
  ])
}

pub fn encode_import_preview(preview: ImportPreview) -> String {
  json.object([
    #("sections", json.array(preview.sections, of: encode_section_result)),
    #("rejected", json.array(preview.rejected, of: encode_rejected_entry)),
    #("shortfall", json.array(preview.shortfall, of: encode_managed_shortfall)),
    #("pruned", json.array(preview.pruned, of: encode_ledger_prune)),
    #("clears_audit_history", json.bool(preview.clears_audit_history)),
  ])
  |> json.to_string
}

pub fn encode_imported_data(imported: ImportResult) -> String {
  json.object([
    #("sections", json.array(imported.sections, of: encode_section_result)),
    #("pruned", json.array(imported.pruned, of: encode_ledger_prune)),
  ])
  |> json.to_string
}

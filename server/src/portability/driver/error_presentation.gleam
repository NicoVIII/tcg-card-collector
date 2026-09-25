import gleam/int
import gleam/list
import gleam/string
import portability/application/commands/import_data/ports as import_data_ports
import portability/domain/export_document
import portability/domain/import_document.{type DocumentError, type Section}
import shared/driver/presented_error.{
  type PresentedError, BadRequest, Internal, PresentedError,
}

/// A whole-file parse problem — bad JSON, wrong `format`, an unsupported
/// `format_version`, or a missing `collection` — is always the client's
/// file, never the server's fault (ADR 0019: import never guesses).
pub fn document_error(error: DocumentError) -> PresentedError {
  PresentedError(BadRequest, import_document.describe_error(error))
}

pub fn import_data(error: import_data_ports.ImportDataError) -> PresentedError {
  case error {
    import_data_ports.NothingToImport ->
      PresentedError(
        BadRequest,
        "The file has no valid entries for format_version "
          <> int.to_string(export_document.format_version)
          <> " to import.",
      )
    import_data_ports.PersistenceFailed(_reason) ->
      PresentedError(Internal, "failed to import the collection")
    import_data_ports.PartiallyWritten(written:, reason: _reason) ->
      PresentedError(
        Internal,
        "import failed after writing "
          <> section_list(written)
          <> " — the rest of the file was not applied",
      )
  }
}

fn section_list(sections: List(Section)) -> String {
  sections
  |> list.map(import_document.section_name)
  |> string.join(", ")
}

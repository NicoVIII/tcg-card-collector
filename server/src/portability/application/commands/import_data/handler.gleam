import gleam/list
import gleam/result
import portability/application/commands/import_data/ports
import portability/domain/import_document.{type ImportDocument}

pub type ImportDataCommand {
  ImportDataCommand(document: ImportDocument)
}

/// Replaces the whole collection with the document's valid entries — the
/// same all-or-nothing snapshot ImportCollection already performs, reached
/// here through Collection's driver/gleam facade (ADR 0019). An entry that
/// failed validation was already dropped by PreviewImport's decode and
/// isn't retried here; a document with none left to import is rejected
/// rather than silently emptying the collection.
pub fn execute(
  command: ImportDataCommand,
  ports: ports.ImportDataPorts,
) -> Result(Int, ports.ImportDataError) {
  let ImportDataCommand(document: document) = command

  case document.collection {
    [] -> Error(ports.NothingToImport)
    entries -> {
      use _ <- result.try(
        ports.replace_collection(entries)
        |> result.map_error(ports.PersistenceFailed),
      )
      Ok(list.length(entries))
    }
  }
}

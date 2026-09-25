import gleam/list
import gleam/option.{None, Some}
import portability/application/commands/import_data/ports
import portability/domain/import_document.{
  type ImportDocument, type Section, type SectionResult, CollectionSection,
  TargetSetsSection,
}

pub type ImportDataCommand {
  ImportDataCommand(document: ImportDocument)
}

type WriteStep {
  WriteStep(section: Section, run: fn() -> Result(Nil, String))
}

/// One step per section present in the document, in a fixed order —
/// insights, then (once #119 adds it) inventory planning, then collection
/// last — so a collection-triggered reconciliation (ADR 0011) always sees
/// the other sections already replaced. A section absent from the file
/// gets no step at all, leaving its data untouched.
fn write_steps(
  document: ImportDocument,
  ports: ports.ImportDataPorts,
) -> List(WriteStep) {
  let target_sets_step = case document.target_sets {
    Some(codes) -> [
      WriteStep(TargetSetsSection, fn() { ports.replace_target_sets(codes) }),
    ]
    None -> []
  }
  let collection_step =
    WriteStep(CollectionSection, fn() {
      ports.replace_collection(document.collection)
    })
  list.append(target_sets_step, [collection_step])
}

/// Runs each step in order, stopping at the first failure. A failure before
/// any step has written yet is a plain PersistenceFailed; once at least one
/// section has committed, a later failure becomes PartiallyWritten, naming
/// what already took effect (ADR 0019).
fn run_steps(
  steps: List(WriteStep),
  written: List(Section),
) -> Result(List(Section), ports.ImportDataError) {
  case steps {
    [] -> Ok(list.reverse(written))
    [step, ..rest] ->
      case step.run() {
        Ok(Nil) -> run_steps(rest, [step.section, ..written])
        Error(reason) ->
          case written {
            [] -> Error(ports.PersistenceFailed(reason))
            _ ->
              Error(ports.PartiallyWritten(
                written: list.reverse(written),
                reason:,
              ))
          }
      }
  }
}

/// Replaces every section present in the document with its valid entries —
/// the same all-or-nothing-per-section snapshot ImportCollection already
/// performs for the collection alone (ADR 0019). An entry that failed
/// validation was already dropped by PreviewImport's decode and isn't
/// retried here; a document with no collection entries left to import is
/// rejected rather than silently emptying the collection — this is the one
/// section that stays mandatory.
pub fn execute(
  command: ImportDataCommand,
  ports: ports.ImportDataPorts,
) -> Result(List(SectionResult), ports.ImportDataError) {
  let ImportDataCommand(document: document) = command

  case document.collection {
    [] -> Error(ports.NothingToImport)
    _ ->
      case run_steps(write_steps(document, ports), []) {
        Ok(_written) -> Ok(import_document.section_results(document))
        Error(error) -> Error(error)
      }
  }
}

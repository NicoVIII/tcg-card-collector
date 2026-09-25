import gleam/list
import gleam/option.{None, Some}
import portability/application/commands/import_data/ports
import portability/domain/import_document.{
  type ImportDocument, type Section, type SectionResult, BulkSection,
  CollectionSection, PlacedSection, RulesSection, TargetSetsSection,
}

pub type ImportDataCommand {
  ImportDataCommand(document: ImportDocument)
}

type WriteStep {
  WriteStep(sections: List(Section), run: fn() -> Result(Nil, String))
}

/// One step per section present in the document, in a fixed order —
/// insights, then inventory planning, then collection last — so a
/// collection-triggered reconciliation (ADR 0011) always sees the ledger
/// already replaced. A section absent from the file gets no step at all,
/// leaving its data untouched. Rules/bulk/placed share one step: they
/// replace atomically together, in one context-level transaction (ADR
/// 0019), not three independent ones.
fn write_steps(
  document: ImportDocument,
  ports: ports.ImportDataPorts,
) -> List(WriteStep) {
  let target_sets_step = case document.target_sets {
    Some(codes) -> [
      WriteStep([TargetSetsSection], fn() { ports.replace_target_sets(codes) }),
    ]
    None -> []
  }
  let plan_step = case plan_sections(document) {
    [] -> []
    sections -> [
      WriteStep(sections, fn() {
        ports.replace_plan(document.rules, document.bulk, document.placed)
      }),
    ]
  }
  let collection_step =
    WriteStep([CollectionSection], fn() {
      ports.replace_collection(document.collection)
    })
  list.flatten([target_sets_step, plan_step, [collection_step]])
}

fn plan_sections(document: ImportDocument) -> List(Section) {
  list.flatten([
    option.map(document.rules, fn(_) { RulesSection }) |> option_to_list,
    option.map(document.bulk, fn(_) { BulkSection }) |> option_to_list,
    option.map(document.placed, fn(_) { PlacedSection }) |> option_to_list,
  ])
}

fn option_to_list(value: option.Option(a)) -> List(a) {
  case value {
    Some(v) -> [v]
    None -> []
  }
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
        Ok(Nil) ->
          run_steps(rest, list.append(list.reverse(step.sections), written))
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
/// performs for the collection alone (ADR 0019). Rules and the bulk spec
/// still need their deep (cross-context) validation resolved here, since
/// PreviewImport's earlier check on the same content isn't trusted as a
/// substitute for this door's own. A document with no collection entries
/// left to import is rejected rather than silently emptying the
/// collection — the one section that stays mandatory.
pub fn execute(
  command: ImportDataCommand,
  ports: ports.ImportDataPorts,
) -> Result(List(SectionResult), ports.ImportDataError) {
  let ImportDataCommand(document: document) = command
  let resolved =
    import_document.resolve_deep_sections(
      document,
      ports.check_rule,
      ports.check_sort_keys,
    )

  case resolved.collection {
    [] -> Error(ports.NothingToImport)
    _ ->
      case run_steps(write_steps(resolved, ports), []) {
        Ok(_written) -> Ok(import_document.section_results(resolved))
        Error(error) -> Error(error)
      }
  }
}

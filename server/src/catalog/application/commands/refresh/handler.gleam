import application/command_result
import catalog/application/commands/refresh/ports.{RefreshCatalogError} as refresh_ports
import catalog/domain/refresh_record.{type RefreshRecord, Import, Skip}
import common/timestamp.{type Timestamp}
import gleam/bool
import gleam/result

pub type RefreshCatalogCommand {
  RefreshCatalogCommand
}

fn import_and_mark(
  record: RefreshRecord,
  meta: refresh_ports.BulkMetadata,
  now: Timestamp,
  import_cards: refresh_ports.ImportCardsPort,
) -> #(
  RefreshRecord,
  command_result.CommandResult(refresh_ports.RefreshCatalogError),
) {
  case import_cards(meta.download_uri) {
    Ok(Nil) -> #(
      refresh_record.mark_succeeded(record, now, meta.updated_at),
      Ok(Nil),
    )
    Error(reason) -> #(
      refresh_record.mark_failed(record, now, reason),
      Error(RefreshCatalogError(reason:)),
    )
  }
}

fn apply_decision(
  record: RefreshRecord,
  meta: refresh_ports.BulkMetadata,
  now: Timestamp,
  import_cards: refresh_ports.ImportCardsPort,
) -> #(
  RefreshRecord,
  command_result.CommandResult(refresh_ports.RefreshCatalogError),
) {
  case refresh_record.decide(record, meta.updated_at) {
    // Upstream was contacted and confirmed current — record the probe time so
    // the interval runs from this contact, not from the previous one.
    Skip -> #(
      refresh_record.mark_skipped(record, now, meta.updated_at),
      Ok(Nil),
    )
    Import -> import_and_mark(record, meta, now, import_cards)
  }
}

pub fn execute(
  _command: RefreshCatalogCommand,
  ports: refresh_ports.RefreshCatalogPorts,
) -> command_result.CommandResult(refresh_ports.RefreshCatalogError) {
  let now = ports.now()
  let record = ports.record_repository.load()

  // No save: upstream was never contacted, so there is nothing to record.
  // The probe interval must count from the last actual upstream contact.
  use <- bool.guard(
    when: !refresh_record.is_probe_due(record, now),
    return: Ok(Nil),
  )
  use meta <- result.try(case ports.fetch_metadata() {
    Ok(meta) -> Ok(meta)
    Error(reason) -> {
      ports.record_repository.save(refresh_record.mark_failed(
        record,
        now,
        reason,
      ))
      Error(RefreshCatalogError(reason:))
    }
  })

  let #(new_record, outcome) =
    apply_decision(record, meta, now, ports.import_cards)
  ports.record_repository.save(new_record)
  outcome
}

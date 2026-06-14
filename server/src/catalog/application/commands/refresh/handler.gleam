import application/command_result
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/domain/refresh_record
import gleam/bool
import gleam/result

pub type RefreshCatalogCommand {
  RefreshCatalogCommand
}

pub fn execute(
  _command: RefreshCatalogCommand,
  ports: refresh_ports.RefreshCatalogPorts,
) -> command_result.CommandResult(refresh_ports.RefreshCatalogError) {
  let now = ports.now()
  let record = ports.record_repository.load()
  use <- bool.guard(
    when: !refresh_record.is_probe_due(record, now),
    return: Ok(Nil),
  )
  use meta <- result.try(
    ports.fetch_metadata()
    |> result.map_error(fn(reason) {
      ports.record_repository.save(refresh_record.mark_failed(
        record,
        now,
        reason,
      ))
      refresh_ports.RefreshCatalogError(message: reason)
    }),
  )
  case refresh_record.decide(record, meta.updated_at) {
    refresh_record.Skip -> {
      ports.record_repository.save(refresh_record.mark_skipped(
        record,
        now,
        meta.updated_at,
      ))
      Ok(Nil)
    }
    refresh_record.Import -> {
      use _ <- result.try(
        ports.import_cards(meta.download_uri)
        |> result.map_error(fn(reason) {
          ports.record_repository.save(refresh_record.mark_failed(
            record,
            now,
            reason,
          ))
          refresh_ports.RefreshCatalogError(
            message: "catalog refresh failed: " <> reason,
          )
        }),
      )
      ports.record_repository.save(refresh_record.mark_succeeded(
        record,
        now,
        meta.updated_at,
      ))
      Ok(Nil)
    }
  }
}

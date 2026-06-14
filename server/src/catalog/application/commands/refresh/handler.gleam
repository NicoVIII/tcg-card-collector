import application/command_result
import catalog/application/commands/refresh/ports
import catalog/domain/refresh_record
import gleam/bool
import gleam/result

pub type RefreshCatalogCommand {
  RefreshCatalogCommand
}

pub fn execute(
  _command: RefreshCatalogCommand,
  port: ports.RefreshCatalogPort,
) -> command_result.CommandResult(ports.RefreshCatalogError) {
  let now = port.now()
  let record = port.load_record()
  use <- bool.guard(
    when: !refresh_record.is_probe_due(record, now),
    return: Ok(Nil),
  )
  use meta <- result.try(
    port.fetch_metadata()
    |> result.map_error(fn(reason) {
      port.save_record(refresh_record.mark_failed(record, now, reason))
      ports.RefreshCatalogError(message: reason)
    }),
  )
  case refresh_record.decide(record, meta.updated_at) {
    refresh_record.Skip -> {
      port.save_record(refresh_record.mark_skipped(record, now, meta.updated_at))
      Ok(Nil)
    }
    refresh_record.Import -> {
      use _ <- result.try(
        port.import_cards(meta.download_uri)
        |> result.map_error(fn(reason) {
          port.save_record(refresh_record.mark_failed(record, now, reason))
          ports.RefreshCatalogError(
            message: "catalog refresh failed: " <> reason,
          )
        }),
      )
      port.save_record(refresh_record.mark_succeeded(
        record,
        now,
        meta.updated_at,
      ))
      Ok(Nil)
    }
  }
}

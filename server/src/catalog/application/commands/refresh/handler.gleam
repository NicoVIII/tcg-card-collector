import application/commands/command_result
import catalog/application/commands/refresh/ports
import gleam/bool
import gleam/result

pub type RefreshCatalogCommand {
  RefreshCatalogCommand
}

pub fn execute(
  _command: RefreshCatalogCommand,
  port: ports.RefreshCatalogPort,
) -> command_result.CommandResult(ports.RefreshCatalogError) {
  use <- bool.guard(when: !port.is_probe_due(), return: Ok(Nil))
  use meta <- result.try(
    port.fetch_metadata()
    |> result.map_error(fn(reason) {
      port.record_failed(reason)
      ports.RefreshCatalogError(message: reason)
    }),
  )
  use <- bool.lazy_guard(
    when: meta.updated_at == port.current_upstream_updated_at(),
    return: fn() {
      port.record_skipped(meta.updated_at)
      Ok(Nil)
    },
  )
  use _ <- result.try(
    port.import_cards(meta.download_uri)
    |> result.map_error(fn(reason) {
      port.record_failed(reason)
      ports.RefreshCatalogError(message: "catalog refresh failed: " <> reason)
    }),
  )
  port.record_succeeded(meta.updated_at)
  Ok(Nil)
}

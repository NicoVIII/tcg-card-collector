// process/application coverage for catalog refresh.
// Covered: import-succeeds happy path.
// Deferred (still owed): skip-unchanged, not-probe-due short-circuit,
//   fetch-metadata failure, import failure.

import catalog/application/commands/refresh/handler
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/domain/refresh_record.{ProbeResult, Succeeded}
import gleam/option.{None, Some}
import gleam/time/timestamp
import support/call_log

const now = 1_000_000

pub fn import_succeeds_persists_succeeded_test() {
  let log = call_log.new()

  let ports =
    refresh_ports.RefreshCatalogPorts(
      now: fn() { timestamp.from_unix_seconds(now) },
      record_repository: refresh_ports.RefreshRecordRepositoryPort(
        load: fn() { None },
        save: fn(record) { call_log.record(log, record) },
      ),
      fetch_metadata: fn() {
        Ok(refresh_ports.BulkMetadata(
          updated_at: "v1",
          download_uri: "https://example/cards",
        ))
      },
      import_cards: fn(_uri) { Ok(Nil) },
    )

  let result = handler.execute(handler.RefreshCatalogCommand, ports)
  assert result == Ok(Nil)

  let assert [saved] = call_log.drain(log)
  let assert ProbeResult(
    last_upstream_updated_at: Some("v1"),
    status: Succeeded,
    ..,
  ) = saved
  Nil
}

// process/application coverage for catalog refresh.
// Covered: import-succeeds happy path, skip-unchanged.
// Deferred (still owed): not-probe-due short-circuit,
//   fetch-metadata failure, import failure.

import catalog/application/commands/refresh/handler
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/domain/refresh_record.{ProbeResult, Skipped, Succeeded}
import gleam/option.{None, Some}
import gleam/time/timestamp
import support/call_log

const now = 1_000_000

fn build_ports(log, load load) {
  refresh_ports.RefreshCatalogPorts(
    now: fn() { timestamp.from_unix_seconds(now) },
    record_repository: refresh_ports.RefreshRecordRepositoryPort(
      load:,
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
}

pub fn import_succeeds_persists_succeeded_test() {
  let log = call_log.new()
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(log, load: fn() { None }),
    )
  assert result == Ok(Nil)

  let assert [saved] = call_log.drain(log)
  let assert ProbeResult(
    last_upstream_updated_at: Some("v1"),
    status: Succeeded,
    ..,
  ) = saved
  Nil
}

pub fn skip_unchanged_persists_skipped_test() {
  let log = call_log.new()
  let prior =
    ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(0),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(log, load: fn() { Some(prior) }),
    )
  assert result == Ok(Nil)

  let assert [saved] = call_log.drain(log)
  let assert ProbeResult(
    last_upstream_updated_at: Some("v1"),
    status: Skipped,
    ..,
  ) = saved
  Nil
}

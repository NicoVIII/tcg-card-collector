// process/application coverage for catalog refresh.
// Covered: import-succeeds, skip-unchanged, probe-not-due,
//   fetch-metadata failure (no prior, with prior), import failure.

import catalog/application/commands/refresh/handler
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/domain/refresh_record.{Failed, ProbeResult, Skipped, Succeeded}
import gleam/option.{None, Some}
import gleam/time/timestamp
import support/call_log

const now = 1_000_000

fn fetch_metadata_ok() {
  Ok(refresh_ports.BulkMetadata(
    updated_at: "v1",
    download_uri: "https://example/cards",
  ))
}

fn import_cards_ok(_) {
  Ok(Nil)
}

fn build_ports(
  log,
  load load,
  fetch_metadata fetch_metadata,
  import_cards import_cards,
) {
  refresh_ports.RefreshCatalogPorts(
    now: fn() { timestamp.from_unix_seconds(now) },
    record_repository: refresh_ports.RefreshRecordRepositoryPort(
      load:,
      save: fn(record) { call_log.record(log, record) },
    ),
    fetch_metadata:,
    import_cards:,
  )
}

pub fn import_succeeds_persists_succeeded_test() {
  let log = call_log.new()
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        log,
        load: fn() { None },
        fetch_metadata: fetch_metadata_ok,
        import_cards: import_cards_ok,
      ),
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
      build_ports(
        log,
        load: fn() { Some(prior) },
        fetch_metadata: fetch_metadata_ok,
        import_cards: import_cards_ok,
      ),
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

pub fn probe_not_due_returns_ok_without_save_test() {
  let log = call_log.new()
  let recent_probe =
    ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now - 1),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        log,
        load: fn() { Some(recent_probe) },
        fetch_metadata: fetch_metadata_ok,
        import_cards: import_cards_ok,
      ),
    )
  assert result == Ok(Nil)
  assert call_log.drain(log) == []
  Nil
}

pub fn fetch_metadata_fails_no_prior_persists_failed_test() {
  let log = call_log.new()
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        log,
        load: fn() { None },
        fetch_metadata: fn() { Error("network error") },
        import_cards: import_cards_ok,
      ),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "network error"))

  let assert [saved] = call_log.drain(log)
  let assert ProbeResult(
    last_upstream_updated_at: None,
    status: Failed(reason: "network error"),
    ..,
  ) = saved
  Nil
}

pub fn fetch_metadata_fails_with_prior_persists_failed_test() {
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
      build_ports(
        log,
        load: fn() { Some(prior) },
        fetch_metadata: fn() { Error("network error") },
        import_cards: import_cards_ok,
      ),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "network error"))

  let assert [saved] = call_log.drain(log)
  let assert ProbeResult(
    last_upstream_updated_at: Some("v1"),
    status: Failed(reason: "network error"),
    ..,
  ) = saved
  Nil
}

pub fn import_fails_persists_failed_test() {
  let log = call_log.new()
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        log,
        load: fn() { None },
        fetch_metadata: fetch_metadata_ok,
        import_cards: fn(_) { Error("import error") },
      ),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "import error"))

  let assert [saved] = call_log.drain(log)
  let assert ProbeResult(
    last_upstream_updated_at: None,
    status: Failed(reason: "import error"),
    ..,
  ) = saved
  Nil
}

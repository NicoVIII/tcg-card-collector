import application/commands/database/refresh/handler
import application/commands/database/refresh/ports
import support/call_log

type Call {
  FetchMetadata
  ImportCards(uri: String)
  RecordSucceeded(updated_at: String)
  RecordSkipped(updated_at: String)
  RecordFailed(reason: String)
}

fn fake_port(
  log: call_log.Log(Call),
  probe_due: Bool,
  upstream: String,
  fetch_result: Result(ports.BulkMetadata, String),
  import_result: Result(Nil, String),
) -> ports.RefreshDatabasePort {
  ports.RefreshDatabasePort(
    is_probe_due: fn() { probe_due },
    current_upstream_updated_at: fn() { upstream },
    fetch_metadata: fn() {
      call_log.record(log, FetchMetadata)
      fetch_result
    },
    import_cards: fn(uri) {
      call_log.record(log, ImportCards(uri))
      import_result
    },
    record_succeeded: fn(at) { call_log.record(log, RecordSucceeded(at)) },
    record_skipped: fn(at) { call_log.record(log, RecordSkipped(at)) },
    record_failed: fn(reason) { call_log.record(log, RecordFailed(reason)) },
  )
}

pub fn not_due_returns_ok_with_no_effects_test() {
  let log = call_log.new()
  let port = fake_port(log, False, "", Error("no fetch"), Error("no import"))

  let result = handler.execute(handler.RefreshDatabaseCommand, port)

  assert result == Ok(Nil)
  assert call_log.drain(log) == []
}

pub fn unchanged_upstream_marks_skipped_test() {
  let updated_at = "2024-01-01T00:00:00.000Z"
  let log = call_log.new()
  let port =
    fake_port(
      log,
      True,
      updated_at,
      Ok(ports.BulkMetadata(
        updated_at: updated_at,
        download_uri: "https://example.com/bulk",
      )),
      Error("no import"),
    )

  let result = handler.execute(handler.RefreshDatabaseCommand, port)

  assert result == Ok(Nil)
  assert call_log.drain(log) == [FetchMetadata, RecordSkipped(updated_at)]
}

pub fn changed_upstream_imports_and_marks_succeeded_test() {
  let updated_at = "2024-02-01T00:00:00.000Z"
  let bulk_uri = "https://example.com/bulk"
  let log = call_log.new()
  let port =
    fake_port(
      log,
      True,
      "2024-01-01T00:00:00.000Z",
      Ok(ports.BulkMetadata(updated_at: updated_at, download_uri: bulk_uri)),
      Ok(Nil),
    )

  let result = handler.execute(handler.RefreshDatabaseCommand, port)

  assert result == Ok(Nil)
  assert call_log.drain(log)
    == [FetchMetadata, ImportCards(bulk_uri), RecordSucceeded(updated_at)]
}

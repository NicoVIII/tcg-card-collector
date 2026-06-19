import catalog/application/commands/refresh/handler
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/domain/refresh_record.{Failed, ProbeResult, Skipped, Succeeded}
import gleam/option.{None, Some}
import gleam/time/timestamp
import support/ref

const now = 1_000_000

fn fetch_metadata_ok() {
  Ok(refresh_ports.BulkMetadata(
    updated_at: "v1",
    download_uri: "https://example/cards",
  ))
}

fn fetch_metadata_fails() {
  Error("network error")
}

fn import_cards_ok(_) {
  Ok(Nil)
}

fn build_ports(
  repo repo,
  fetch_metadata fetch_metadata,
  import_cards import_cards,
) {
  refresh_ports.RefreshCatalogPorts(
    now: fn() { timestamp.from_unix_seconds(now) },
    record_repository: refresh_ports.RefreshRecordRepositoryPort(
      load: fn() { ref.get(repo) },
      save: fn(record) { ref.set(repo, Some(record)) },
    ),
    fetch_metadata:,
    import_cards:,
  )
}

pub fn import_succeeds_persists_succeeded_test() {
  let repo = ref.new(None)
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        repo:,
        fetch_metadata: fetch_metadata_ok,
        import_cards: import_cards_ok,
      ),
    )
  assert result == Ok(Nil)

  let assert Some(saved) = ref.get(repo)
  assert saved
    == ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
}

pub fn skip_unchanged_persists_skipped_test() {
  let prior =
    ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(0),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  let repo = ref.new(Some(prior))
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        repo:,
        fetch_metadata: fetch_metadata_ok,
        import_cards: import_cards_ok,
      ),
    )
  assert result == Ok(Nil)

  let assert Some(saved) = ref.get(repo)
  assert saved
    == ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now),
      last_upstream_updated_at: Some("v1"),
      status: Skipped,
    )
}

pub fn probe_not_due_returns_ok_without_save_test() {
  let recent_probe =
    ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now - 1),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  let repo = ref.new(Some(recent_probe))
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(repo:, fetch_metadata: fn() { panic }, import_cards: fn(_) {
        panic
      }),
    )
  assert result == Ok(Nil)
  assert ref.get(repo) == Some(recent_probe)
}

pub fn fetch_metadata_fails_no_prior_persists_failed_test() {
  let repo = ref.new(None)
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        repo:,
        fetch_metadata: fetch_metadata_fails,
        import_cards: import_cards_ok,
      ),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "network error"))

  let assert Some(saved) = ref.get(repo)
  assert saved
    == ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now),
      last_upstream_updated_at: None,
      status: Failed(reason: "network error"),
    )
}

pub fn fetch_metadata_fails_with_prior_persists_failed_test() {
  let prior =
    ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(0),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  let repo = ref.new(Some(prior))
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(
        repo:,
        fetch_metadata: fetch_metadata_fails,
        import_cards: import_cards_ok,
      ),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "network error"))

  let assert Some(saved) = ref.get(repo)
  assert saved
    == ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now),
      last_upstream_updated_at: Some("v1"),
      status: Failed(reason: "network error"),
    )
}

pub fn import_fails_persists_failed_test() {
  let repo = ref.new(None)
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(repo:, fetch_metadata: fetch_metadata_ok, import_cards: fn(_) {
        Error("import error")
      }),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "import error"))

  let assert Some(saved) = ref.get(repo)
  // create_failed preserves the prior's last_upstream_updated_at (None here,
  // since there was no prior record), not the just-fetched metadata version.
  assert saved
    == ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now),
      last_upstream_updated_at: None,
      status: Failed(reason: "import error"),
    )
}

pub fn import_fails_with_prior_persists_failed_test() {
  // Prior has "v0" (different from what fetch returns), so decide → Import.
  // On import failure, create_failed preserves "v0" (what the DB holds),
  // not "v1" (what was just fetched but not yet imported).
  let prior =
    ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(0),
      last_upstream_updated_at: Some("v0"),
      status: Succeeded,
    )
  let repo = ref.new(Some(prior))
  let result =
    handler.execute(
      handler.RefreshCatalogCommand,
      build_ports(repo:, fetch_metadata: fetch_metadata_ok, import_cards: fn(_) {
        Error("import error")
      }),
    )
  assert result
    == Error(refresh_ports.RefreshCatalogError(reason: "import error"))

  let assert Some(saved) = ref.get(repo)
  assert saved
    == ProbeResult(
      last_probe_at: timestamp.from_unix_seconds(now),
      last_upstream_updated_at: Some("v0"),
      status: Failed(reason: "import error"),
    )
}

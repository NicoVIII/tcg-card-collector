import common/timestamp.{type Timestamp}
import gleam/option.{type Option, None, Some}

const one_day_seconds = 86_400

pub type RefreshStatus {
  Succeeded
  Skipped
  Failed(reason: String)
}

pub type RefreshRecord {
  NeverRefreshed
  Probed(
    last_probe_at: Timestamp,
    last_upstream_updated_at: Option(String),
    status: RefreshStatus,
  )
}

pub type RefreshDecision {
  Skip
  Import
}

/// A probe is always due when there is no prior record or the last attempt
/// failed (immediate retry). For successful or version-current probes, we wait one day.
pub fn is_probe_due(record: RefreshRecord, now: Timestamp) -> Bool {
  case record {
    NeverRefreshed -> True
    Probed(status: Failed(_), ..) -> True
    Probed(last_probe_at:, ..) ->
      timestamp.difference_seconds(now, last_probe_at) >= one_day_seconds
  }
}

/// Skip when the upstream version matches what we already imported; otherwise
/// fetch and import.
pub fn decide(
  record: RefreshRecord,
  fetched_updated_at: String,
) -> RefreshDecision {
  case record {
    NeverRefreshed -> Import
    Probed(last_upstream_updated_at: Some(stored), ..)
      if stored == fetched_updated_at
    -> Skip
    Probed(..) -> Import
  }
}

pub fn mark_succeeded(
  _record: RefreshRecord,
  now: Timestamp,
  upstream_updated_at: String,
) -> RefreshRecord {
  Probed(
    last_probe_at: now,
    last_upstream_updated_at: Some(upstream_updated_at),
    status: Succeeded,
  )
}

pub fn mark_skipped(
  _record: RefreshRecord,
  now: Timestamp,
  upstream_updated_at: String,
) -> RefreshRecord {
  Probed(
    last_probe_at: now,
    last_upstream_updated_at: Some(upstream_updated_at),
    status: Skipped,
  )
}

/// On failure, preserve the prior upstream version so we know what is actually
/// in the DB, and retry immediately next probe.
pub fn mark_failed(
  record: RefreshRecord,
  now: Timestamp,
  reason: String,
) -> RefreshRecord {
  let prior_upstream = case record {
    NeverRefreshed -> None
    Probed(last_upstream_updated_at: ua, ..) -> ua
  }
  Probed(
    last_probe_at: now,
    last_upstream_updated_at: prior_upstream,
    status: Failed(reason),
  )
}

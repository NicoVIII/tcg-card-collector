import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

pub type RefreshStatus {
  Succeeded
  Skipped
  Failed(reason: String)
}

pub type ProbeResult {
  ProbeResult(
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
pub fn is_probe_due(record: Option(ProbeResult), now: Timestamp) -> Bool {
  case record {
    None -> True
    Some(ProbeResult(status: Failed(_), ..)) -> True
    Some(ProbeResult(last_probe_at:, ..)) ->
      duration.compare(
        timestamp.difference(last_probe_at, now),
        duration.hours(24),
      )
      != order.Lt
  }
}

/// Skip when the upstream version matches what we already imported; otherwise
/// fetch and import.
pub fn decide(
  record: Option(ProbeResult),
  fetched_updated_at: String,
) -> RefreshDecision {
  case record {
    None -> Import
    Some(ProbeResult(last_upstream_updated_at: Some(stored), ..))
      if stored == fetched_updated_at
    -> Skip
    Some(ProbeResult(..)) -> Import
  }
}

/// On failure, preserve the prior upstream version so we know what is actually
/// in the DB, and retry immediately next probe.
pub fn create_failed(
  previous: Option(ProbeResult),
  now: Timestamp,
  reason: String,
) -> ProbeResult {
  let prior_upstream = case previous {
    None -> None
    Some(ProbeResult(last_upstream_updated_at: ua, ..)) -> ua
  }
  ProbeResult(
    last_probe_at: now,
    last_upstream_updated_at: prior_upstream,
    status: Failed(reason),
  )
}

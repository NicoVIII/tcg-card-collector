import catalog/domain/refresh_record.{
  Failed, Import, NeverRefreshed, Probed, Skip, Skipped, Succeeded,
}
import common/timestamp
import gleam/option.{None, Some}

// ── helpers ──────────────────────────────────────────────────────────────────

fn ts(epoch: Int) -> timestamp.Timestamp {
  timestamp.from_epoch_seconds(epoch)
}

const one_day = 86_400

const now = 1_000_000

// ── is_probe_due ─────────────────────────────────────────────────────────────

pub fn never_refreshed_is_always_due_test() {
  assert refresh_record.is_probe_due(NeverRefreshed, ts(now)) == True
}

pub fn failed_probe_is_always_due_test() {
  let record =
    Probed(
      last_probe_at: ts(now),
      last_upstream_updated_at: None,
      status: Failed("network error"),
    )
  assert refresh_record.is_probe_due(record, ts(now)) == True
}

pub fn just_probed_succeeded_is_not_due_test() {
  let record =
    Probed(
      last_probe_at: ts(now),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  assert refresh_record.is_probe_due(record, ts(now)) == False
}

pub fn stale_succeeded_over_one_day_is_due_test() {
  let record =
    Probed(
      last_probe_at: ts(now - one_day),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  assert refresh_record.is_probe_due(record, ts(now)) == True
}

pub fn stale_skipped_over_one_day_is_due_test() {
  let record =
    Probed(
      last_probe_at: ts(now - one_day),
      last_upstream_updated_at: Some("v1"),
      status: Skipped,
    )
  assert refresh_record.is_probe_due(record, ts(now)) == True
}

pub fn almost_one_day_is_not_due_test() {
  let record =
    Probed(
      last_probe_at: ts(now - one_day + 1),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  assert refresh_record.is_probe_due(record, ts(now)) == False
}

// ── decide ───────────────────────────────────────────────────────────────────

pub fn never_refreshed_decides_import_test() {
  assert refresh_record.decide(NeverRefreshed, "v1") == Import
}

pub fn matching_upstream_decides_skip_test() {
  let record =
    Probed(
      last_probe_at: ts(now),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  assert refresh_record.decide(record, "v1") == Skip
}

pub fn different_upstream_decides_import_test() {
  let record =
    Probed(
      last_probe_at: ts(now),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  assert refresh_record.decide(record, "v2") == Import
}

pub fn no_prior_upstream_decides_import_test() {
  let record =
    Probed(
      last_probe_at: ts(now),
      last_upstream_updated_at: None,
      status: Succeeded,
    )
  assert refresh_record.decide(record, "v1") == Import
}

// ── mark_failed ──────────────────────────────────────────────────────────────

pub fn mark_failed_preserves_prior_upstream_from_succeeded_test() {
  let record =
    Probed(
      last_probe_at: ts(now - one_day),
      last_upstream_updated_at: Some("v1"),
      status: Succeeded,
    )
  let failed = refresh_record.mark_failed(record, ts(now), "timeout")
  let assert Probed(
    last_upstream_updated_at: Some("v1"),
    status: Failed("timeout"),
    ..,
  ) = failed
  Nil
}

pub fn mark_failed_preserves_none_upstream_from_never_refreshed_test() {
  let failed = refresh_record.mark_failed(NeverRefreshed, ts(now), "timeout")
  let assert Probed(
    last_upstream_updated_at: None,
    status: Failed("timeout"),
    ..,
  ) = failed
  Nil
}

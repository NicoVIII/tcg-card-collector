import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import inventory_planning/domain/location_ref.{type LocationRef}
import inventory_planning/domain/placed_ledger_reconciliation.{
  type PlacedRow, PlacedRow,
}
import shared/domain/copy_key.{type CopyKey}

/// What walking a location found, per kind of copy, beyond what simply
/// matched the ledger (#108). A Confirmed copy needs no write, so it never
/// reaches the server. An Unexpected copy with a source was misfiled from
/// there and moves; without one it was never ticked and is marked here.
pub type Finding {
  Missing(key: CopyKey, quantity: Int)
  Unexpected(key: CopyKey, quantity: Int, source: Option(LocationRef))
}

/// One completed walk over a single location: merged findings that are
/// internally consistent, not yet checked against the ledger.
pub opaque type LocationAudit {
  LocationAudit(
    location: LocationRef,
    missing: List(#(CopyKey, Int)),
    unexpected: List(#(#(CopyKey, Option(LocationRef)), Int)),
  )
}

pub type InvalidAudit {
  NonPositiveQuantity
  SourceIsAuditedLocation
  MissingAndUnexpected(CopyKey)
}

/// A finding the current ledger or collection contradicts — the client holds
/// both, so it means the page went stale, not a choice left to the server.
pub type Rejection {
  NotRecordedHere(key: CopyKey, requested: Int, recorded: Int)
  NotRecordedAtSource(
    key: CopyKey,
    source: LocationRef,
    requested: Int,
    recorded: Int,
  )
  ExceedsOwned(key: CopyKey, requested: Int, available: Int)
}

/// The placed-ledger writes a completed audit amounts to, in the DAO's
/// "amount to add / subtract" shape.
pub type LedgerChanges {
  LedgerChanges(decrements: List(PlacedRow), increments: List(PlacedRow))
}

/// One completed audit in the history.
pub type AuditRecord {
  AuditRecord(location: LocationRef, completed_at: Timestamp)
}

fn validate_finding(
  location: LocationRef,
  finding: Finding,
) -> Result(Nil, InvalidAudit) {
  use <- bool.guard(finding.quantity < 1, Error(NonPositiveQuantity))
  case finding {
    Unexpected(source: Some(source), ..) if source == location ->
      Error(SourceIsAuditedLocation)
    _ -> Ok(Nil)
  }
}

fn sum_by(pairs: List(#(k, Int))) -> List(#(k, Int)) {
  pairs
  |> list.fold(dict.new(), fn(acc, pair) {
    dict.upsert(acc, pair.0, fn(existing) {
      option.unwrap(existing, 0) + pair.1
    })
  })
  |> dict.to_list
}

fn split_findings(
  findings: List(Finding),
) -> #(List(#(CopyKey, Int)), List(#(#(CopyKey, Option(LocationRef)), Int))) {
  let missing =
    list.filter_map(findings, fn(finding) {
      case finding {
        Missing(key:, quantity:) -> Ok(#(key, quantity))
        Unexpected(..) -> Error(Nil)
      }
    })
  let unexpected =
    list.filter_map(findings, fn(finding) {
      case finding {
        Unexpected(key:, quantity:, source:) -> Ok(#(#(key, source), quantity))
        Missing(..) -> Error(Nil)
      }
    })
  #(sum_by(missing), sum_by(unexpected))
}

// A copy can't be both short of and beyond what the ledger records here.
fn check_disjoint(
  missing: List(#(CopyKey, Int)),
  unexpected: List(#(#(CopyKey, Option(LocationRef)), Int)),
) -> Result(Nil, InvalidAudit) {
  let missing_keys = list.map(missing, fn(pair) { pair.0 })
  case
    list.find(unexpected, fn(pair) { list.contains(missing_keys, pair.0.0) })
  {
    Ok(#(#(key, _), _)) -> Error(MissingAndUnexpected(key))
    Error(Nil) -> Ok(Nil)
  }
}

/// Merges findings that share a key (and, for Unexpected, a source) and
/// rejects an inconsistent set. No findings at all is valid: everything was
/// confirmed, and the audit still completes.
pub fn new(
  location: LocationRef,
  findings: List(Finding),
) -> Result(LocationAudit, InvalidAudit) {
  use _ <- result.try(list.try_each(findings, validate_finding(location, _)))
  let #(missing, unexpected) = split_findings(findings)
  use _ <- result.try(check_disjoint(missing, unexpected))
  Ok(LocationAudit(location:, missing:, unexpected:))
}

pub fn location(audit: LocationAudit) -> LocationRef {
  audit.location
}

fn recorded_at(
  ledger: List(PlacedRow),
  key: CopyKey,
  location: LocationRef,
) -> Int {
  ledger
  |> list.filter(fn(row) { row.key == key && row.location == location })
  |> list.fold(0, fn(sum, row) { sum + row.quantity })
}

fn placed_total(ledger: List(PlacedRow), key: CopyKey) -> Int {
  ledger
  |> list.filter(fn(row) { row.key == key })
  |> list.fold(0, fn(sum, row) { sum + row.quantity })
}

fn check_missing(
  audit: LocationAudit,
  ledger: List(PlacedRow),
  pair: #(CopyKey, Int),
) -> Result(PlacedRow, Rejection) {
  let #(key, requested) = pair
  let recorded = recorded_at(ledger, key, audit.location)
  use <- bool.guard(
    requested > recorded,
    Error(NotRecordedHere(key:, requested:, recorded:)),
  )
  Ok(PlacedRow(key:, location: audit.location, quantity: requested))
}

fn check_move(
  ledger: List(PlacedRow),
  key: CopyKey,
  source: LocationRef,
  requested: Int,
) -> Result(Nil, Rejection) {
  let recorded = recorded_at(ledger, key, source)
  use <- bool.guard(
    requested > recorded,
    Error(NotRecordedAtSource(key:, source:, requested:, recorded:)),
  )
  Ok(Nil)
}

// Marking without a source adds to the key's placed total; it must stay
// within what the collection owns. Moves leave the total unchanged, and a
// key with a Missing finding can't also be Unexpected, so the ledger's own
// total is the baseline.
fn check_within_owned(
  ledger: List(PlacedRow),
  owned: Dict(CopyKey, Int),
  key: CopyKey,
  requested: Int,
) -> Result(Nil, Rejection) {
  let owned_quantity = dict.get(owned, key) |> result.unwrap(0)
  let available = int.max(0, owned_quantity - placed_total(ledger, key))
  use <- bool.guard(
    requested > available,
    Error(ExceedsOwned(key:, requested:, available:)),
  )
  Ok(Nil)
}

fn unsourced_totals(audit: LocationAudit) -> List(#(CopyKey, Int)) {
  audit.unexpected
  |> list.filter_map(fn(pair) {
    case pair {
      #(#(key, None), quantity) -> Ok(#(key, quantity))
      #(#(_, Some(_)), _) -> Error(Nil)
    }
  })
}

fn check_unexpected(
  audit: LocationAudit,
  ledger: List(PlacedRow),
  pair: #(#(CopyKey, Option(LocationRef)), Int),
) -> Result(List(#(PlacedRow, PlacedRow)), Rejection) {
  let #(#(key, source), quantity) = pair
  let here = PlacedRow(key:, location: audit.location, quantity:)
  case source {
    Some(source) -> {
      use _ <- result.map(check_move(ledger, key, source, quantity))
      [#(PlacedRow(key:, location: source, quantity:), here)]
    }
    None -> Ok([])
  }
}

fn compare_rows(a: PlacedRow, b: PlacedRow) -> order.Order {
  location_ref.compare(a.location, b.location)
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.set_code_string(a.key),
      copy_key.set_code_string(b.key),
    )
  })
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.collector_number_string(a.key),
      copy_key.collector_number_string(b.key),
    )
  })
  |> order.lazy_break_tie(fn() {
    string.compare(copy_key.finish_string(a.key), copy_key.finish_string(b.key))
  })
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.language_string(a.key),
      copy_key.language_string(b.key),
    )
  })
}

/// Checks the audit against the current ledger and owned quantities and
/// returns the writes completing it amounts to: Missing copies come off this
/// location, sourced Unexpected copies move here from their source, unsourced
/// ones are added here. The first contradiction rejects the whole audit.
pub fn ledger_changes(
  audit: LocationAudit,
  ledger: List(PlacedRow),
  owned: Dict(CopyKey, Int),
) -> Result(LedgerChanges, Rejection) {
  use missing <- result.try(
    list.try_map(audit.missing, check_missing(audit, ledger, _)),
  )
  use moves <- result.try(
    list.try_map(audit.unexpected, check_unexpected(audit, ledger, _))
    |> result.map(list.flatten),
  )
  let unsourced = unsourced_totals(audit)
  use _ <- result.try(
    list.try_each(unsourced, fn(pair) {
      check_within_owned(ledger, owned, pair.0, pair.1)
    }),
  )
  let marks =
    list.map(unsourced, fn(pair) {
      PlacedRow(key: pair.0, location: audit.location, quantity: pair.1)
    })
  Ok(LedgerChanges(
    decrements: list.append(missing, list.map(moves, fn(move) { move.0 }))
      |> list.sort(compare_rows),
    increments: list.append(marks, list.map(moves, fn(move) { move.1 }))
      |> list.sort(compare_rows),
  ))
}

/// The latest completion per location (LastAuditedAt), ordered by location.
pub fn latest_per_location(records: List(AuditRecord)) -> List(AuditRecord) {
  records
  |> list.fold(dict.new(), fn(acc, record) {
    dict.upsert(acc, record.location, fn(existing) {
      case existing {
        Some(current) ->
          case timestamp.compare(record.completed_at, current) {
            order.Gt -> record.completed_at
            _ -> current
          }
        None -> record.completed_at
      }
    })
  })
  |> dict.to_list
  |> list.map(fn(pair) { AuditRecord(location: pair.0, completed_at: pair.1) })
  |> list.sort(fn(a, b) { location_ref.compare(a.location, b.location) })
}

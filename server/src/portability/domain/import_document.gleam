import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import portability/domain/export_document.{
  type AuditEntry, type BulkSpec, type CollectionEntry,
  type ManagedLocationEntry, type MemberEntry, type PlacedEntry, type PlacedIn,
  type Rule, AuditEntry, CollectionEntry, InLocation, InManagedLocation,
  ManagedLocationEntry, MemberEntry, PlacedEntry,
}
import shared/domain/copy_key.{type CopyKey}
import shared/domain/set_code

/// The five fields a collection entry carries on the wire, before
/// validation — everything defaults to an empty/zero value rather than
/// failing the whole document, so a malformed entry can still be reported
/// with whatever identity it did carry (driver/export_file.gleam builds
/// this from the decoded JSON).
pub type RawEntry {
  RawEntry(
    set_code: String,
    collector_number: String,
    quantity: Int,
    finish: String,
    language: String,
  )
}

/// A placed-ledger entry as it arrives on the wire, before validation — same
/// shape as RawEntry plus where it sits: exactly one of `location` (a rule
/// target or bulk) and `managed_location` (a managed location's name, v2 on)
/// may be non-blank.
pub type RawPlaced {
  RawPlaced(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    location: String,
    managed_location: String,
    quantity: Int,
  )
}

pub type RawManagedLocation {
  RawManagedLocation(name: String, kind: String)
}

pub type RawMember {
  RawMember(
    managed_location: String,
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

/// An audit-history entry as it arrives on the wire (v3 on), before
/// validation: exactly one of `location` and `managed_location` may be
/// non-blank, as in RawPlaced, and `completed_at` is RFC 3339 text.
pub type RawAudit {
  RawAudit(location: String, managed_location: String, completed_at: String)
}

/// Which part of the document an entry or a count belongs to — #119 widened
/// the document beyond the collection alone, so every rejection and every
/// written count now names the section it came from.
pub type Section {
  CollectionSection
  TargetSetsSection
  RulesSection
  BulkSection
  ManagedLocationsSection
  MembersSection
  PlacedSection
  AuditsSection
}

pub fn section_name(section: Section) -> String {
  case section {
    CollectionSection -> "collection"
    TargetSetsSection -> "insights.target_sets"
    RulesSection -> "inventory_planning.rules"
    BulkSection -> "inventory_planning.bulk"
    ManagedLocationsSection -> "inventory_planning.managed_locations"
    MembersSection -> "inventory_planning.managed_location_members"
    PlacedSection -> "inventory_planning.placed"
    AuditsSection -> "inventory_planning.audits"
  }
}

/// A rejected entry, identified by its section plus its 1-based position
/// within that section's array and its raw identity — JSON carries no line
/// numbers, and a position survives an editor's reformatting the way a line
/// number wouldn't. The singleton bulk spec always reports position 1.
pub type RejectedEntry {
  RejectedEntry(
    section: Section,
    position: Int,
    identity: String,
    reason: String,
  )
}

/// How many entries a section will write (preview) or did write (import
/// result) — the same shape serves both, since by the time either is built
/// the document's sections already hold only validated entries. The bulk
/// spec is a singleton: its count is always 1 when present.
pub type SectionResult {
  SectionResult(section: Section, count: Int)
}

/// A placed-ledger row ReconcilePlacedLedger prunes right after import (ADR
/// 0011): `quantity` copies leave `location`'s ledger. Shown before the
/// import and again after, so the collector can check those locations.
pub type LedgerPrune {
  LedgerPrune(identity: String, location: PlacedIn, quantity: Int)
}

/// A managed location's member the imported collection can't supply — the
/// shortfall Inventory Planning's projection will show right after import
/// (ADR 0022), predicted from the document alone.
pub type ManagedShortfall {
  ManagedShortfall(location_name: String, identity: String, missing: Int)
}

pub type ImportDocument {
  ImportDocument(
    collection: List(CollectionEntry),
    rejected: List(RejectedEntry),
    /// Each field is None when its section is absent from the file, so
    /// import leaves that data untouched; Some([]) (or Some(spec) for bulk)
    /// replaces it, even when empty — the same present-but-empty posture as
    /// every other section (ADR 0019).
    target_sets: Option(List(String)),
    rules: Option(List(Rule)),
    bulk: Option(BulkSpec),
    /// Members only exist with their managed locations: a file with
    /// members but no managed_locations section has every member rejected.
    managed_locations: Option(List(ManagedLocationEntry)),
    members: Option(List(MemberEntry)),
    placed: Option(List(PlacedEntry)),
    audits: Option(List(AuditEntry)),
  )
}

fn option_list_result(
  value: Option(List(a)),
  section: Section,
) -> List(SectionResult) {
  case value {
    Some(items) -> [SectionResult(section, list.length(items))]
    None -> []
  }
}

/// One entry per section actually present in the document, valid-entry
/// counts only — a section absent from the file (an older export, or one
/// this build doesn't recognise) has no entry here.
pub fn section_results(document: ImportDocument) -> List(SectionResult) {
  [SectionResult(CollectionSection, list.length(document.collection))]
  |> list.append(option_list_result(document.target_sets, TargetSetsSection))
  |> list.append(option_list_result(document.rules, RulesSection))
  |> list.append(case document.bulk {
    Some(_) -> [SectionResult(BulkSection, 1)]
    None -> []
  })
  |> list.append(option_list_result(
    document.managed_locations,
    ManagedLocationsSection,
  ))
  |> list.append(option_list_result(document.members, MembersSection))
  |> list.append(option_list_result(document.placed, PlacedSection))
  |> list.append(option_list_result(document.audits, AuditsSection))
}

fn key_identity(key: CopyKey) -> String {
  copy_key.set_code_string(key)
  <> " "
  <> copy_key.collector_number_string(key)
  <> " "
  <> copy_key.finish_string(key)
  <> " "
  <> copy_key.language_string(key)
}

/// The managed locations with their members, as one restore part. Members
/// without their managed locations never get here (every one is rejected for
/// naming an unknown location), so the managed section alone decides it.
pub fn managed_with_members(
  document: ImportDocument,
) -> Option(#(List(ManagedLocationEntry), List(MemberEntry))) {
  option.map(document.managed_locations, fn(locations) {
    #(locations, option.unwrap(document.members, []))
  })
}

/// Names a pruned ledger row the way the import preview names every copy.
pub fn ledger_prune(entry: PlacedEntry) -> LedgerPrune {
  LedgerPrune(
    identity: key_identity(entry.key),
    location: entry.location,
    quantity: entry.quantity,
  )
}

fn owned_quantities(
  collection: List(CollectionEntry),
) -> dict.Dict(CopyKey, Int) {
  collection
  |> list.map(fn(entry) { #(entry.key, entry.quantity) })
  |> dict.from_list
}

fn take_member(
  state: #(dict.Dict(CopyKey, Int), List(ManagedShortfall)),
  location_name: String,
  member: MemberEntry,
) -> #(dict.Dict(CopyKey, Int), List(ManagedShortfall)) {
  let #(remaining, acc) = state
  case member.managed_location == location_name {
    False -> state
    True -> {
      let available = dict.get(remaining, member.key) |> result.unwrap(0)
      let taken = int.min(available, member.quantity)
      let remaining = dict.insert(remaining, member.key, available - taken)
      case member.quantity - taken {
        0 -> #(remaining, acc)
        missing -> #(remaining, [
          ManagedShortfall(
            location_name:,
            identity: key_identity(member.key),
            missing:,
          ),
          ..acc
        ])
      }
    }
  }
}

/// Every member the imported collection can't supply, walking managed
/// locations in the projection's own precedence (by name, ADR 0022): a
/// scarce copy goes to the location whose name sorts first.
pub fn managed_shortfall(
  collection: List(CollectionEntry),
  managed_locations: List(ManagedLocationEntry),
  members: List(MemberEntry),
) -> List(ManagedShortfall) {
  let #(_, shortfalls_rev) =
    managed_locations
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })
    |> list.fold(#(owned_quantities(collection), []), fn(state, location) {
      list.fold(members, state, fn(state, member) {
        take_member(state, location.name, member)
      })
    })
  list.reverse(shortfalls_rev)
}

/// Whole-file problems, checked before any entry is parsed (ADR 0019: the
/// importer reads format_version first and rejects the whole file, naming
/// the version found, before parsing any section).
pub type DocumentError {
  NotJson
  NotThisFormat
  UnsupportedVersion(found: String)
  MissingCollection
}

pub fn describe_error(error: DocumentError) -> String {
  case error {
    NotJson -> "The file is not valid JSON."
    NotThisFormat -> "The file is not a tcg-card-collector export."
    UnsupportedVersion(found) ->
      "Unsupported format_version \""
      <> found
      <> "\" — this build reads format_version "
      <> int.to_string(export_document.oldest_format_version)
      <> " through "
      <> int.to_string(export_document.format_version)
      <> "."
    MissingCollection -> "The file has no \"collection\" array."
  }
}

fn split_outcomes(
  outcomes: List(Result(a, RejectedEntry)),
) -> #(List(a), List(RejectedEntry)) {
  #(
    list.filter_map(outcomes, fn(outcome) {
      case outcome {
        Ok(value) -> Ok(value)
        Error(_) -> Error(Nil)
      }
    }),
    list.filter_map(outcomes, fn(outcome) {
      case outcome {
        Error(rejected) -> Ok(rejected)
        Ok(_) -> Error(Nil)
      }
    }),
  )
}

fn identity(entry: RawEntry) -> String {
  entry.set_code
  <> " "
  <> entry.collector_number
  <> " "
  <> entry.finish
  <> " "
  <> entry.language
}

fn validate_entry(
  position: Int,
  entry: RawEntry,
) -> Result(CollectionEntry, RejectedEntry) {
  case
    copy_key.from_user_input(
      set_code: entry.set_code,
      collector_number: entry.collector_number,
      finish: entry.finish,
      language: entry.language,
    )
  {
    Error(key_error) ->
      Error(RejectedEntry(
        section: CollectionSection,
        position:,
        identity: identity(entry),
        reason: copy_key.describe_error(key_error),
      ))
    Ok(_) if entry.quantity < 1 ->
      Error(RejectedEntry(
        section: CollectionSection,
        position:,
        identity: identity(entry),
        reason: "quantity must be at least 1",
      ))
    Ok(key) -> Ok(CollectionEntry(key:, quantity: entry.quantity))
  }
}

/// Validates a batch of raw entries positionally: a bad one becomes a
/// RejectedEntry naming its position and identity, while the rest still
/// import — an all-valid-rows-except-these-lines shape.
pub fn validate_entries(
  raw: List(RawEntry),
) -> #(List(CollectionEntry), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(entry, index) { validate_entry(index + 1, entry) })
  split_outcomes(outcomes)
}

/// Validates `insights.target_sets` positionally, same shape as
/// `validate_entries`: each code is canonicalised through the shared-kernel
/// `SetCode` (` GRN ` imports as `grn`), and a blank code, or one an earlier
/// entry already spelled, is rejected. `InsightsApi.replace_target_sets`
/// re-validates at write time (ADR 0019: defense in depth, not a
/// caller-facing filter).
pub fn validate_target_sets(
  raw: List(String),
) -> #(List(String), List(RejectedEntry)) {
  let #(_, outcomes_rev) =
    list.index_fold(raw, #(set.new(), []), fn(state, raw_code, index) {
      let #(seen, acc) = state
      let reject = fn(reason) {
        Error(RejectedEntry(
          section: TargetSetsSection,
          position: index + 1,
          identity: raw_code,
          reason:,
        ))
      }
      case set_code.from_user_input(raw_code) {
        Error(_) -> #(seen, [reject("set code is blank"), ..acc])
        Ok(code) -> {
          let code = set_code.to_string(code)
          case set.contains(seen, code) {
            True -> #(seen, [reject("set code is listed twice"), ..acc])
            False -> #(set.insert(seen, code), [Ok(code), ..acc])
          }
        }
      }
    })
  split_outcomes(list.reverse(outcomes_rev))
}

pub fn managed_names(locations: List(ManagedLocationEntry)) -> Set(String) {
  locations
  |> list.map(fn(location) { location.name })
  |> set.from_list
}

/// Validates `inventory_planning.managed_locations` positionally: a blank
/// name, or a name an earlier entry already used, is rejected. The kind is
/// checked later, by Inventory Planning (`resolve_deep_sections`).
pub fn validate_managed_locations(
  raw: List(RawManagedLocation),
) -> #(List(ManagedLocationEntry), List(RejectedEntry)) {
  let #(_, outcomes_rev) =
    list.index_fold(raw, #(set.new(), []), fn(state, entry, index) {
      let #(seen, acc) = state
      let name = string.trim(entry.name)
      let reject = fn(reason) {
        Error(RejectedEntry(
          section: ManagedLocationsSection,
          position: index + 1,
          identity: entry.name,
          reason:,
        ))
      }
      case name, set.contains(seen, name) {
        "", _ -> #(seen, [reject("name is blank"), ..acc])
        _, True -> #(seen, [reject("name is used twice"), ..acc])
        _, False -> #(set.insert(seen, name), [
          Ok(ManagedLocationEntry(name:, kind: entry.kind)),
          ..acc
        ])
      }
    })
  split_outcomes(list.reverse(outcomes_rev))
}

fn member_identity(entry: RawMember) -> String {
  entry.managed_location
  <> " "
  <> entry.set_code
  <> " "
  <> entry.collector_number
  <> " "
  <> entry.finish
  <> " "
  <> entry.language
}

fn validate_member(
  position: Int,
  entry: RawMember,
  managed_names: Set(String),
) -> Result(MemberEntry, RejectedEntry) {
  let reject = fn(reason) {
    Error(RejectedEntry(
      section: MembersSection,
      position:,
      identity: member_identity(entry),
      reason:,
    ))
  }
  let name = string.trim(entry.managed_location)
  case
    copy_key.from_user_input(
      set_code: entry.set_code,
      collector_number: entry.collector_number,
      finish: entry.finish,
      language: entry.language,
    )
  {
    Error(key_error) -> reject(copy_key.describe_error(key_error))
    Ok(_) if entry.quantity < 1 -> reject("quantity must be at least 1")
    Ok(key) ->
      case set.contains(managed_names, name) {
        False -> reject("no managed location named \"" <> name <> "\"")
        True ->
          Ok(MemberEntry(managed_location: name, key:, quantity: entry.quantity))
      }
  }
}

/// Validates `inventory_planning.managed_location_members` positionally;
/// each must name one of `managed_names` — the document's own valid
/// managed locations.
pub fn validate_members(
  raw: List(RawMember),
  managed_names: Set(String),
) -> #(List(MemberEntry), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(entry, index) {
      validate_member(index + 1, entry, managed_names)
    })
  split_outcomes(outcomes)
}

fn placed_identity(entry: RawPlaced) -> String {
  entry.set_code
  <> " "
  <> entry.collector_number
  <> " "
  <> entry.finish
  <> " "
  <> entry.language
  <> " "
  <> case entry.managed_location {
    "" -> entry.location
    name -> name
  }
}

// A placed entry and an audit name their location the same way.
fn named_location(
  location: String,
  managed_location: String,
  managed_names: Set(String),
) -> Result(PlacedIn, String) {
  case string.trim(location), string.trim(managed_location) {
    "", "" -> Error("location is blank")
    location, "" -> Ok(InLocation(location))
    "", name ->
      case set.contains(managed_names, name) {
        True -> Ok(InManagedLocation(name))
        False -> Error("no managed location named \"" <> name <> "\"")
      }
    _, _ -> Error("names both a location and a managed location")
  }
}

fn validate_placed_entry(
  position: Int,
  entry: RawPlaced,
  managed_names: Set(String),
) -> Result(PlacedEntry, RejectedEntry) {
  let reject = fn(reason) {
    Error(RejectedEntry(
      section: PlacedSection,
      position:,
      identity: placed_identity(entry),
      reason:,
    ))
  }
  case
    copy_key.from_user_input(
      set_code: entry.set_code,
      collector_number: entry.collector_number,
      finish: entry.finish,
      language: entry.language,
    )
  {
    Error(key_error) -> reject(copy_key.describe_error(key_error))
    Ok(_) if entry.quantity < 1 -> reject("quantity must be at least 1")
    Ok(key) ->
      case
        named_location(entry.location, entry.managed_location, managed_names)
      {
        Error(reason) -> reject(reason)
        Ok(location) ->
          Ok(PlacedEntry(key:, location:, quantity: entry.quantity))
      }
  }
}

/// Validates `inventory_planning.placed` positionally — pure, like
/// `validate_entries`: a copy's identity and location need no other
/// context's parser to check. A managed-location entry must name one of
/// `managed_names` — the document's own valid managed locations.
pub fn validate_placed(
  raw: List(RawPlaced),
  managed_names: Set(String),
) -> #(List(PlacedEntry), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(entry, index) {
      validate_placed_entry(index + 1, entry, managed_names)
    })
  split_outcomes(outcomes)
}

fn audit_identity(entry: RawAudit) -> String {
  case entry.managed_location {
    "" -> entry.location
    name -> name
  }
  <> " "
  <> entry.completed_at
}

fn validate_audit(
  position: Int,
  entry: RawAudit,
  managed_names: Set(String),
) -> Result(AuditEntry, RejectedEntry) {
  let reject = fn(reason) {
    RejectedEntry(
      section: AuditsSection,
      position:,
      identity: audit_identity(entry),
      reason:,
    )
  }
  use location <- result.try(
    named_location(entry.location, entry.managed_location, managed_names)
    |> result.map_error(reject),
  )
  use completed_at <- result.map(
    timestamp.parse_rfc3339(string.trim(entry.completed_at))
    |> result.replace_error(reject("completed_at is not an RFC 3339 time")),
  )
  AuditEntry(location:, completed_at:)
}

/// Validates `inventory_planning.audits` positionally, same location rule as
/// `validate_placed`.
pub fn validate_audits(
  raw: List(RawAudit),
  managed_names: Set(String),
) -> #(List(AuditEntry), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(entry, index) {
      validate_audit(index + 1, entry, managed_names)
    })
  split_outcomes(outcomes)
}

/// Validates every rule's DSL fields via an injected checker — Portability's
/// own domain can't reach Inventory Planning's parsers directly (same
/// boundary reasoning as target sets), so the application layer supplies
/// `check_rule`, built from InventoryPlanningApi.check_rule at the
/// infrastructure boundary (ADR 0019).
pub fn validate_rules(
  raw: List(Rule),
  check_rule: fn(Rule) -> Result(Nil, String),
) -> #(List(Rule), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(rule, index) {
      case check_rule(rule) {
        Ok(Nil) -> Ok(rule)
        Error(reason) ->
          Error(RejectedEntry(
            section: RulesSection,
            position: index + 1,
            identity: rule.location,
            reason:,
          ))
      }
    })
  split_outcomes(outcomes)
}

/// Validates the bulk spec via an injected checker, same boundary reasoning
/// as `validate_rules`.
pub fn validate_bulk(
  raw: Option(BulkSpec),
  check_bulk_spec: fn(BulkSpec) -> Result(Nil, String),
) -> #(Option(BulkSpec), List(RejectedEntry)) {
  case raw {
    None -> #(None, [])
    Some(spec) ->
      case check_bulk_spec(spec) {
        Ok(Nil) -> #(Some(spec), [])
        Error(reason) -> #(None, [
          RejectedEntry(
            section: BulkSection,
            position: 1,
            identity: spec.location,
            reason:,
          ),
        ])
      }
  }
}

/// The checkers Portability's own domain can't implement — each wraps an
/// Inventory Planning parser reached through its facade (ADR 0019).
pub type DeepCheckers {
  DeepCheckers(
    check_rule: fn(Rule) -> Result(Nil, String),
    check_bulk_spec: fn(BulkSpec) -> Result(Nil, String),
    check_managed_kind: fn(String) -> Result(Nil, String),
  )
}

fn check_managed_kinds(
  raw: Option(List(ManagedLocationEntry)),
  check_managed_kind: fn(String) -> Result(Nil, String),
) -> #(Option(List(ManagedLocationEntry)), List(RejectedEntry)) {
  case raw {
    None -> #(None, [])
    Some(locations) -> {
      let outcomes =
        list.index_map(locations, fn(location, index) {
          case check_managed_kind(location.kind) {
            Ok(Nil) -> Ok(location)
            Error(reason) ->
              Error(RejectedEntry(
                section: ManagedLocationsSection,
                position: index + 1,
                identity: location.name,
                reason:,
              ))
          }
        })
      let #(valid, rejected) = split_outcomes(outcomes)
      #(Some(valid), rejected)
    }
  }
}

fn rejected_location_reason(name: String) -> String {
  "its managed location \"" <> name <> "\" was rejected"
}

// Positions here are within the already-validated list, not the file — the
// file position was lost when the section was first validated. The identity
// still names the entry unambiguously.
fn drop_entries_at(
  entries: Option(List(a)),
  dropped: Set(String),
  section: Section,
  managed_name: fn(a) -> Option(String),
  identity: fn(a) -> String,
) -> #(Option(List(a)), List(RejectedEntry)) {
  let check = fn(entry, index) {
    case managed_name(entry) {
      None -> Ok(entry)
      Some(name) -> {
        use <- bool.guard(!set.contains(dropped, name), Ok(entry))
        Error(RejectedEntry(
          section:,
          position: index + 1,
          identity: identity(entry),
          reason: rejected_location_reason(name),
        ))
      }
    }
  }
  case entries {
    None -> #(None, [])
    Some(entries) -> {
      let #(valid, rejected) = split_outcomes(list.index_map(entries, check))
      #(Some(valid), rejected)
    }
  }
}

fn managed_name_of(location: PlacedIn) -> Option(String) {
  case location {
    InManagedLocation(name) -> Some(name)
    InLocation(_) -> None
  }
}

fn audit_entry_identity(entry: AuditEntry) -> String {
  let name = case entry.location {
    InLocation(name) -> name
    InManagedLocation(name) -> name
  }
  name <> " " <> timestamp.to_rfc3339(entry.completed_at, calendar.utc_offset)
}

/// Runs the one validation pass Portability's own domain can't do alone —
/// rules, the bulk spec, and managed-location kinds need Inventory
/// Planning's parsers, reached only through `checkers` (ADR 0019). Both
/// PreviewImport and ImportData call this on the document
/// `export_file.parse` produced, before doing anything else with it, so the
/// two doors validate identically. A section absent from the document
/// (`None`) is left as-is — there is nothing to check. A managed location
/// rejected here takes its members, placed entries, and audits with it, each
/// reported, so nothing is left pointing at it.
pub fn resolve_deep_sections(
  document: ImportDocument,
  checkers: DeepCheckers,
) -> ImportDocument {
  let #(rules, rules_rejected) = case document.rules {
    None -> #(None, [])
    Some(raw) -> {
      let #(valid, rejected) = validate_rules(raw, checkers.check_rule)
      #(Some(valid), rejected)
    }
  }
  let #(bulk, bulk_rejected) =
    validate_bulk(document.bulk, checkers.check_bulk_spec)
  let #(managed_locations, managed_rejected) =
    check_managed_kinds(document.managed_locations, checkers.check_managed_kind)
  let dropped =
    set.difference(
      managed_names(option.unwrap(document.managed_locations, [])),
      managed_names(option.unwrap(managed_locations, [])),
    )
  let #(members, members_rejected) =
    drop_entries_at(
      document.members,
      dropped,
      MembersSection,
      fn(member) { Some(member.managed_location) },
      fn(member) { key_identity(member.key) },
    )
  let #(placed, placed_rejected) =
    drop_entries_at(
      document.placed,
      dropped,
      PlacedSection,
      fn(entry) { managed_name_of(entry.location) },
      fn(entry) { key_identity(entry.key) },
    )
  let #(audits, audits_rejected) =
    drop_entries_at(
      document.audits,
      dropped,
      AuditsSection,
      fn(entry) { managed_name_of(entry.location) },
      audit_entry_identity,
    )
  ImportDocument(
    ..document,
    rules:,
    bulk:,
    managed_locations:,
    members:,
    placed:,
    audits:,
    rejected: list.flatten([
      document.rejected,
      rules_rejected,
      bulk_rejected,
      managed_rejected,
      members_rejected,
      placed_rejected,
      audits_rejected,
    ]),
  )
}

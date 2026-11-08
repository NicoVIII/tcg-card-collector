import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import portability/domain/export_document.{
  type BulkSpec, type CollectionEntry, type ManagedLocationEntry,
  type MemberEntry, type PlacedEntry, type PlacedIn, type Rule, CollectionEntry,
  InLocation, InManagedLocation, ManagedLocationEntry, MemberEntry, PlacedEntry,
}
import shared/domain/copy_key.{type CopyKey}

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

/// A placed-ledger copy the imported collection doesn't own enough of —
/// computed up front so the preview can say what ReconcilePlacedLedger will
/// prune right after import (ADR 0011). Needs no cross-context call:
/// `collection` and `placed` are both already Portability's own validated
/// domain data by the time this runs.
pub type LedgerExcess {
  LedgerExcess(identity: String, placed: Int, owned: Int)
}

/// A managed location's member the imported collection can't supply — the
/// shortfall Inventory Planning's projection will show right after import
/// (ADR 0022), predicted from the document alone the same way LedgerExcess
/// predicts ReconcilePlacedLedger.
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

fn owned_quantities(
  collection: List(CollectionEntry),
) -> dict.Dict(CopyKey, Int) {
  collection
  |> list.map(fn(entry) { #(entry.key, entry.quantity) })
  |> dict.from_list
}

/// Every placed key whose total across locations exceeds what the imported
/// collection owns — what ReconcilePlacedLedger prunes right after import
/// (ADR 0011), computed here so the preview can say so before anything is
/// written.
pub fn ledger_excess(
  collection: List(CollectionEntry),
  placed: List(PlacedEntry),
) -> List(LedgerExcess) {
  let owned = owned_quantities(collection)

  placed
  |> list.fold(dict.new(), fn(acc, entry) {
    dict.upsert(acc, entry.key, fn(existing) {
      option.unwrap(existing, 0) + entry.quantity
    })
  })
  |> dict.to_list
  |> list.filter_map(fn(pair) {
    let #(key, placed_total) = pair
    let owned_qty = dict.get(owned, key) |> result.unwrap(0)
    case placed_total > owned_qty {
      True ->
        Ok(LedgerExcess(
          identity: key_identity(key),
          placed: placed_total,
          owned: owned_qty,
        ))
      False -> Error(Nil)
    }
  })
  |> list.sort(fn(a, b) { string.compare(a.identity, b.identity) })
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

fn validate_target_set(
  position: Int,
  raw: String,
) -> Result(String, RejectedEntry) {
  case string.trim(raw) {
    "" ->
      Error(RejectedEntry(
        section: TargetSetsSection,
        position:,
        identity: raw,
        reason: "set code is blank",
      ))
    trimmed -> Ok(trimmed)
  }
}

/// Validates `insights.target_sets` positionally, same shape as
/// `validate_entries`. Only a blank code is rejected here — Portability's
/// own domain can't reach Insights' `target_set.parse` (that would cross
/// the bounded-context boundary outside the allowed driver/gleam facade
/// link), so `InsightsApi.replace_target_sets` re-validates at write time
/// (ADR 0019: defense in depth, not a caller-facing filter).
pub fn validate_target_sets(
  raw: List(String),
) -> #(List(String), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(set_code, index) {
      validate_target_set(index + 1, set_code)
    })
  split_outcomes(outcomes)
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

fn placed_location(
  entry: RawPlaced,
  managed_names: Set(String),
) -> Result(PlacedIn, String) {
  case string.trim(entry.location), string.trim(entry.managed_location) {
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
      case placed_location(entry, managed_names) {
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

/// Validates the bulk spec's sort keys via an injected checker, same
/// boundary reasoning as `validate_rules`. The location isn't checked — any
/// string is a valid bulk location, matching Inventory Planning's own
/// UpdateBulkSpec.
pub fn validate_bulk(
  raw: Option(BulkSpec),
  check_sort_keys: fn(String) -> Result(Nil, String),
) -> #(Option(BulkSpec), List(RejectedEntry)) {
  case raw {
    None -> #(None, [])
    Some(spec) ->
      case check_sort_keys(spec.sort_keys) {
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
    check_sort_keys: fn(String) -> Result(Nil, String),
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
fn drop_members_of(
  members: Option(List(MemberEntry)),
  dropped: Set(String),
) -> #(Option(List(MemberEntry)), List(RejectedEntry)) {
  case members {
    None -> #(None, [])
    Some(entries) -> {
      let outcomes =
        list.index_map(entries, fn(member, index) {
          case set.contains(dropped, member.managed_location) {
            False -> Ok(member)
            True ->
              Error(RejectedEntry(
                section: MembersSection,
                position: index + 1,
                identity: key_identity(member.key),
                reason: rejected_location_reason(member.managed_location),
              ))
          }
        })
      let #(valid, rejected) = split_outcomes(outcomes)
      #(Some(valid), rejected)
    }
  }
}

fn placed_at_dropped(entry: PlacedEntry, dropped: Set(String)) -> Bool {
  case entry.location {
    InManagedLocation(name) -> set.contains(dropped, name)
    InLocation(_) -> False
  }
}

fn drop_placed_at(
  placed: Option(List(PlacedEntry)),
  dropped: Set(String),
) -> #(Option(List(PlacedEntry)), List(RejectedEntry)) {
  case placed {
    None -> #(None, [])
    Some(entries) -> {
      let outcomes =
        list.index_map(entries, fn(entry, index) {
          case entry.location, placed_at_dropped(entry, dropped) {
            InManagedLocation(name), True ->
              Error(RejectedEntry(
                section: PlacedSection,
                position: index + 1,
                identity: key_identity(entry.key),
                reason: rejected_location_reason(name),
              ))
            _, _ -> Ok(entry)
          }
        })
      let #(valid, rejected) = split_outcomes(outcomes)
      #(Some(valid), rejected)
    }
  }
}

/// Runs the one validation pass Portability's own domain can't do alone —
/// rules, the bulk spec, and managed-location kinds need Inventory
/// Planning's parsers, reached only through `checkers` (ADR 0019). Both
/// PreviewImport and ImportData call this on the document
/// `export_file.parse` produced, before doing anything else with it, so the
/// two doors validate identically. A section absent from the document
/// (`None`) is left as-is — there is nothing to check. A managed location
/// rejected here takes its members and placed entries with it, each
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
    validate_bulk(document.bulk, checkers.check_sort_keys)
  let #(managed_locations, managed_rejected) =
    check_managed_kinds(document.managed_locations, checkers.check_managed_kind)
  let dropped =
    set.difference(
      managed_names(option.unwrap(document.managed_locations, [])),
      managed_names(option.unwrap(managed_locations, [])),
    )
  let #(members, members_rejected) = drop_members_of(document.members, dropped)
  let #(placed, placed_rejected) = drop_placed_at(document.placed, dropped)
  ImportDocument(
    ..document,
    rules:,
    bulk:,
    managed_locations:,
    members:,
    placed:,
    rejected: list.flatten([
      document.rejected,
      rules_rejected,
      bulk_rejected,
      managed_rejected,
      members_rejected,
      placed_rejected,
    ]),
  )
}

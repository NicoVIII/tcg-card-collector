import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import portability/domain/export_document.{type CollectionEntry, CollectionEntry}
import shared/domain/copy_key

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

/// Which part of the document an entry or a count belongs to — #119 widened
/// the document beyond the collection alone, so every rejection and every
/// written count now names the section it came from.
pub type Section {
  CollectionSection
  TargetSetsSection
}

pub fn section_name(section: Section) -> String {
  case section {
    CollectionSection -> "collection"
    TargetSetsSection -> "insights.target_sets"
  }
}

/// A rejected entry, identified by its section plus its 1-based position
/// within that section's array and its raw identity — JSON carries no line
/// numbers, and a position survives an editor's reformatting the way a line
/// number wouldn't.
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
/// the document's sections already hold only validated entries.
pub type SectionResult {
  SectionResult(section: Section, count: Int)
}

pub type ImportDocument {
  ImportDocument(
    collection: List(CollectionEntry),
    rejected: List(RejectedEntry),
    /// None when the file has no "insights" section at all, so import
    /// leaves target sets untouched; Some([]) clears every target set, same
    /// as any other present-but-empty section (ADR 0019).
    target_sets: Option(List(String)),
  )
}

/// One entry per section actually present in the document, valid-entry
/// counts only — a section absent from the file (an older export, or one
/// this build doesn't recognise) has no entry here.
pub fn section_results(document: ImportDocument) -> List(SectionResult) {
  [SectionResult(CollectionSection, list.length(document.collection))]
  |> list.append(case document.target_sets {
    Some(codes) -> [SectionResult(TargetSetsSection, list.length(codes))]
    None -> []
  })
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
      <> int.to_string(export_document.format_version)
      <> "."
    MissingCollection -> "The file has no \"collection\" array."
  }
}

/// Validates a batch of raw entries positionally: a bad one becomes a
/// RejectedEntry naming its position and identity, while the rest still
/// import — the same all-valid-rows-except-these-lines shape the deckstats
/// importer already reports.
pub fn validate_entries(
  raw: List(RawEntry),
) -> #(List(CollectionEntry), List(RejectedEntry)) {
  let outcomes =
    list.index_map(raw, fn(entry, index) { validate_entry(index + 1, entry) })
  #(
    list.filter_map(outcomes, fn(outcome) {
      case outcome {
        Ok(entry) -> Ok(entry)
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
  #(
    list.filter_map(outcomes, fn(outcome) {
      case outcome {
        Ok(set_code) -> Ok(set_code)
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

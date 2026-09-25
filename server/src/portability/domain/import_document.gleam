import gleam/int
import gleam/list
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

/// A rejected entry, identified by its 1-based position in the document's
/// `collection` array plus its raw identity — JSON carries no line numbers,
/// and a position survives an editor's reformatting the way a line number
/// wouldn't.
pub type RejectedEntry {
  RejectedEntry(position: Int, identity: String, reason: String)
}

pub type ImportDocument {
  ImportDocument(
    collection: List(CollectionEntry),
    rejected: List(RejectedEntry),
  )
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
        position:,
        identity: identity(entry),
        reason: copy_key.describe_error(key_error),
      ))
    Ok(_) if entry.quantity < 1 ->
      Error(RejectedEntry(
        position:,
        identity: identity(entry),
        reason: "quantity must be at least 1",
      ))
    Ok(key) -> Ok(CollectionEntry(key:, quantity: entry.quantity))
  }
}

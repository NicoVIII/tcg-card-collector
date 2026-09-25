import gleam/int
import portability/domain/export_document
import portability/domain/import_document.{
  MissingCollection, NotJson, NotThisFormat, RawEntry, RejectedEntry,
  UnsupportedVersion,
}
import shared/domain/copy_key

fn a_raw_entry(
  set_code: String,
  collector_number: String,
  quantity: Int,
  finish: String,
  language: String,
) -> import_document.RawEntry {
  RawEntry(set_code:, collector_number:, quantity:, finish:, language:)
}

pub fn a_valid_entry_at_its_position_test() {
  let #(entries, rejected) =
    import_document.validate_entries([a_raw_entry("mh2", "17", 2, "foil", "en")])

  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  assert entries == [export_document.CollectionEntry(key:, quantity: 2)]
  assert rejected == []
}

pub fn an_unrecognized_finish_is_rejected_with_its_position_and_identity_test() {
  let #(entries, rejected) =
    import_document.validate_entries([
      a_raw_entry("mh2", "17", 2, "foill", "en"),
    ])

  assert entries == []
  assert rejected
    == [
      RejectedEntry(
        position: 1,
        identity: "mh2 17 foill en",
        reason: "unknown finish",
      ),
    ]
}

pub fn a_quantity_below_one_is_rejected_test() {
  let #(entries, rejected) =
    import_document.validate_entries([a_raw_entry("mh2", "17", 0, "foil", "en")])

  assert entries == []
  assert rejected
    == [
      RejectedEntry(
        position: 1,
        identity: "mh2 17 foil en",
        reason: "quantity must be at least 1",
      ),
    ]
}

pub fn a_bad_entry_does_not_block_the_rest_and_positions_stay_1_based_test() {
  let #(entries, rejected) =
    import_document.validate_entries([
      a_raw_entry("mh2", "17", 2, "foill", "en"),
      a_raw_entry("dmu", "101", 3, "etched", "zhs"),
    ])

  let assert Ok(dmu_key) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "etched",
      language: "zhs",
    )
  assert entries == [export_document.CollectionEntry(key: dmu_key, quantity: 3)]
  assert rejected
    == [
      RejectedEntry(
        position: 1,
        identity: "mh2 17 foill en",
        reason: "unknown finish",
      ),
    ]
}

pub fn describes_every_document_error_test() {
  assert import_document.describe_error(NotJson)
    == "The file is not valid JSON."
  assert import_document.describe_error(NotThisFormat)
    == "The file is not a tcg-card-collector export."
  assert import_document.describe_error(MissingCollection)
    == "The file has no \"collection\" array."
  assert import_document.describe_error(UnsupportedVersion("2"))
    == "Unsupported format_version \"2\" — this build reads format_version "
    <> int.to_string(export_document.format_version)
    <> "."
}

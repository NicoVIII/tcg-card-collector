import collection/infrastructure/daos/collection_dao
import portability/domain/export_document.{CollectionEntry}
import portability/infrastructure/adapters/queries/export_data/adapter
import shared/domain/copy_key
import support/test_db

pub fn reads_the_collection_through_the_collection_facade_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.upsert_cards([
      collection_dao.CardRow(
        set_code: "dmu",
        collector_number: "101",
        finish: "etched",
        language: "zhs",
        quantity: 1,
      ),
      collection_dao.CardRow(
        set_code: "mh2",
        collector_number: "17",
        finish: "foil",
        language: "en",
        quantity: 2,
      ),
    ])

  let ports = adapter.new()
  let assert Ok(entries) = ports.list_collection_entries()

  let assert Ok(dmu_key) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "etched",
      language: "zhs",
    )
  let assert Ok(mh2_key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )

  assert entries
    == [
      CollectionEntry(key: dmu_key, quantity: 1),
      CollectionEntry(key: mh2_key, quantity: 2),
    ]
}

pub fn an_empty_collection_reads_as_no_entries_test() {
  use _db <- test_db.with_temp_db()

  let ports = adapter.new()

  assert ports.list_collection_entries() == Ok([])
}

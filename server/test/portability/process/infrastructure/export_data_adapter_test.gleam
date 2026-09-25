import collection/infrastructure/daos/collection_dao
import inventory_planning/infrastructure/daos/inventory_rules_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import portability/domain/export_document.{
  BulkSpec, CollectionEntry, PlacedEntry, Rule,
}
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

pub fn reads_rules_bulk_and_placed_through_the_inventory_planning_facade_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    inventory_rules_dao.upsert(inventory_rules_dao.RuleRow(
      id: "rule-1",
      location_name: "Binder A",
      expression: "rarity >= rare",
      position: 0,
      selector: "all",
      sort_keys: "",
    ))
  let assert Ok(Nil) =
    placed_cards_dao.increment([
      placed_cards_dao.PlacedCardRow(
        set_code: "mh2",
        collector_number: "17",
        finish: "foil",
        language: "en",
        location: "Binder A",
        quantity: 2,
      ),
    ])

  let ports = adapter.new()
  let assert Ok(mh2_key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )

  assert ports.list_rules()
    == Ok([
      Rule(
        location: "Binder A",
        expression: "rarity >= rare",
        selector: "all",
        sort_keys: "",
      ),
    ])
  assert ports.get_bulk_spec()
    == Ok(BulkSpec(location: "Bulk", sort_keys: "color_identity,type,name"))
  assert ports.list_placed()
    == Ok([PlacedEntry(key: mh2_key, location: "Binder A", quantity: 2)])
}

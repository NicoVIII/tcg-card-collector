import application/collection_import/ports as collection_import_ports
import application/inventory_planning/ports as inventory_ports
import application/settings/ports as settings_ports
import driver/skir/card_catalog_handler
import driver/skir/collection_import_handler
import driver/skir/inventory_planning_handler
import driver/skir/settings_handler
import gleam/list
import gleeunit
import gleeunit/should
import infrastructure/card_catalog/sqlite_repository as card_catalog_sqlite
import infrastructure/collection_import/sqlite_repository as collection_import_sqlite
import infrastructure/inventory_planning/sqlite_repository as inventory_planning_sqlite
import infrastructure/settings/sqlite_repository as settings_sqlite

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn card_catalog_handler_lists_empty_catalog_test() {
  card_catalog_sqlite.reset_for_tests()
  let repository = card_catalog_sqlite.new()
  let cards = card_catalog_handler.list_catalog_cards(repository)
  should.equal(list.length(cards), 0)
}

pub fn card_catalog_handler_lists_seeded_cards_test() {
  card_catalog_sqlite.reset_for_tests()
  card_catalog_sqlite.seed_card("card-1", "Lightning Bolt", "M11")
  card_catalog_sqlite.seed_card("card-2", "Counterspell", "2XM")
  let repository = card_catalog_sqlite.new()
  let cards = card_catalog_handler.list_catalog_cards(repository)
  should.equal(list.length(cards), 2)
}

pub fn collection_import_handler_returns_not_found_when_empty_test() {
  collection_import_sqlite.reset_for_tests()
  let repository = collection_import_sqlite.new()
  let response = collection_import_handler.get_latest_import_status(repository)
  should.equal(response, collection_import_handler.ImportStatusNotFound)
}

pub fn collection_import_handler_returns_latest_saved_import_status_test() {
  collection_import_sqlite.reset_for_tests()
  let repository = collection_import_sqlite.new()

  let _ =
    collection_import_handler.import_collection(
      repository,
      collection_import_handler.ImportCollectionRequest(
        import_run_id: "run-1",
        source_name: "deckstats-export.csv",
        source_checksum: "checksum-1",
        row_count: 1,
        rows: [
          collection_import_handler.ImportCollectionRow(
            card_name: "Lightning Bolt",
            set_code: "M11",
            collector_number: "146",
            quantity: 42,
          ),
        ],
      ),
    )

  let response = collection_import_handler.get_latest_import_status(repository)

  should.equal(
    response,
    collection_import_handler.ImportStatusFound(
      collection_import_ports.ImportRunReadModel(
        "run-1",
        "deckstats-export.csv",
        "succeeded",
        1,
      ),
    ),
  )
}

pub fn inventory_handler_lists_empty_rules_test() {
  inventory_planning_sqlite.reset_for_tests()
  let repository = inventory_planning_sqlite.new()
  let rules = inventory_planning_handler.list_inventory_rules(repository)
  should.equal(list.length(rules), 0)
}

pub fn inventory_handler_upsert_and_list_rules_test() {
  inventory_planning_sqlite.reset_for_tests()
  let repository = inventory_planning_sqlite.new()

  let upsert_result =
    inventory_planning_handler.upsert_inventory_rule(
      repository,
      inventory_planning_handler.UpsertInventoryRuleRequest(
        id: "rule-1",
        location_name: "main-binder",
        expression: "set_code=M11",
      ),
    )
  should.equal(upsert_result, Ok(Nil))

  let rules = inventory_planning_handler.list_inventory_rules(repository)
  should.equal(list.length(rules), 1)
}

pub fn inventory_handler_delete_rule_removes_it_test() {
  inventory_planning_sqlite.reset_for_tests()
  let repository = inventory_planning_sqlite.new()

  let upsert_result =
    inventory_planning_handler.upsert_inventory_rule(
      repository,
      inventory_planning_handler.UpsertInventoryRuleRequest(
        id: "rule-2",
        location_name: "binder-b",
        expression: "set_code=2XM",
      ),
    )
  should.equal(upsert_result, Ok(Nil))

  inventory_planning_handler.delete_inventory_rule(
    repository,
    inventory_planning_handler.DeleteInventoryRuleRequest(id: "rule-2"),
  )

  let rules = inventory_planning_handler.list_inventory_rules(repository)
  should.equal(list.length(rules), 0)
}

pub fn settings_handler_returns_defaults_when_not_set_test() {
  settings_sqlite.reset_for_tests()
  let repository = settings_sqlite.new()
  let settings = settings_handler.get_settings(repository)
  should.equal(settings.default_sort, "card_name")
  should.equal(settings.default_grouping, "location_name")
}

pub fn settings_handler_persists_updated_values_test() {
  settings_sqlite.reset_for_tests()
  let repository = settings_sqlite.new()

  settings_handler.update_settings(
    repository,
    settings_handler.UpdateSettingsRequest(
      default_sort: "set_code",
      default_grouping: "finish",
    ),
  )

  let settings = settings_handler.get_settings(repository)
  should.equal(
    settings,
    settings_ports.AppSettingsReadModel(
      default_sort: "set_code",
      default_grouping: "finish",
    ),
  )
}

pub fn inventory_handler_returns_empty_projection_test() {
  collection_import_sqlite.reset_for_tests()
  inventory_planning_sqlite.reset_for_tests()

  let import_repository = collection_import_sqlite.new()
  let inventory_repository = inventory_planning_sqlite.new()

  let _ =
    collection_import_handler.import_collection(
      import_repository,
      collection_import_handler.ImportCollectionRequest(
        import_run_id: "projection-run-1",
        source_name: "integration-test.csv",
        source_checksum: "checksum-projection",
        row_count: 2,
        rows: [
          collection_import_handler.ImportCollectionRow(
            card_name: "Lightning Bolt",
            set_code: "M11",
            collector_number: "146",
            quantity: 2,
          ),
          collection_import_handler.ImportCollectionRow(
            card_name: "Counterspell",
            set_code: "2XM",
            collector_number: "49",
            quantity: 1,
          ),
        ],
      ),
    )

  let upsert_result =
    inventory_planning_handler.upsert_inventory_rule(
      inventory_repository,
      inventory_planning_handler.UpsertInventoryRuleRequest(
        id: "projection-rule-1",
        location_name: "main-binder",
        expression: "set_code=M11",
      ),
    )
  should.equal(upsert_result, Ok(Nil))

  let repository = inventory_planning_sqlite.new()
  let projection =
    inventory_planning_handler.inventory_projection(
      repository,
      inventory_planning_handler.InventoryProjectionRequest(
        sort_by: "card_name",
        group_by: "location_name",
      ),
    )

  should.equal(
    projection,
    Ok([
      inventory_ports.InventoryProjectionReadModel(
        location_name: "main-binder",
        card_name: "Lightning Bolt",
        set_code: "M11",
        quantity: 2,
        group_value: "main-binder",
      ),
    ]),
  )
}

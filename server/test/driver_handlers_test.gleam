import driver/skir/card_catalog_handler
import driver/skir/collection_import_handler
import driver/skir/inventory_planning_handler
import gleam/list
import gleeunit
import gleeunit/should
import infrastructure/card_catalog/sqlite_repository as card_catalog_sqlite
import infrastructure/collection_import/sqlite_repository as collection_import_sqlite
import infrastructure/inventory_planning/sqlite_repository as inventory_planning_sqlite

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn card_catalog_handler_lists_stub_card_test() {
  let repository = card_catalog_sqlite.new()
  let cards = card_catalog_handler.list_catalog_cards(repository)
  should.equal(list.length(cards), 1)
}

pub fn collection_import_handler_returns_not_found_when_empty_test() {
  let repository = collection_import_sqlite.new()
  let response = collection_import_handler.get_latest_import_status(repository)
  should.equal(response, collection_import_handler.ImportStatusNotFound)
}

pub fn inventory_handler_lists_empty_rules_test() {
  let repository = inventory_planning_sqlite.new()
  let rules = inventory_planning_handler.list_inventory_rules(repository)
  should.equal(list.length(rules), 0)
}

pub fn inventory_handler_returns_empty_projection_test() {
  let repository = inventory_planning_sqlite.new()
  let projection =
    inventory_planning_handler.inventory_projection(
      repository,
      inventory_planning_handler.InventoryProjectionRequest(
        sort_by: "card_name",
        group_by: "location",
      ),
    )

  should.equal(list.length(projection), 0)
}

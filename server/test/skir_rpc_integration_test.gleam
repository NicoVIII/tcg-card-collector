import composition
import driver/skir/setup
import gleeunit
import gleeunit/should
import infrastructure/card_catalog/sqlite_repository as card_catalog_sqlite
import infrastructure/collection_import/sqlite_repository as collection_import_sqlite
import infrastructure/inventory_planning/sqlite_repository as inventory_planning_sqlite
import infrastructure/settings/sqlite_repository as settings_sqlite
import skir_client/service

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn skir_command_success_import_collection_test() {
  let deps = fresh_dependencies()
  let rpc_service = setup.make_service()

  let request =
    "ImportCollection:201:readable:{"
    <> "\"import_run_id\":\"run-rpc-1\","
    <> "\"source_name\":\"rpc-source.csv\","
    <> "\"source_checksum\":\"rpc-checksum\","
    <> "\"row_count\":1,"
    <> "\"rows\":[{"
    <> "\"card_name\":\"Lightning Bolt\","
    <> "\"set_code\":\"M11\","
    <> "\"collector_number\":\"146\","
    <> "\"quantity\":1"
    <> "}]"
    <> "}"

  let #(raw, _) = service.handle_request(rpc_service, request, Nil, deps)

  should.equal(raw.status_code, 200)
}

pub fn skir_command_error_upsert_inventory_rule_test() {
  let deps = fresh_dependencies()
  let rpc_service = setup.make_service()

  let request =
    "UpsertInventoryRule:301:readable:{"
    <> "\"id\":\"rule-rpc-invalid\","
    <> "\"location_name\":\"main-binder\","
    <> "\"expression\":\"rarity=common\""
    <> "}"

  let #(raw, _) = service.handle_request(rpc_service, request, Nil, deps)

  should.equal(raw.status_code, 400)
  should.equal(raw.data, "invalid inventory rule expression")
}

pub fn skir_query_success_get_latest_import_status_test() {
  let deps = fresh_dependencies()
  let rpc_service = setup.make_service()

  let import_request =
    "ImportCollection:201:readable:{"
    <> "\"import_run_id\":\"run-rpc-2\","
    <> "\"source_name\":\"rpc-source.csv\","
    <> "\"source_checksum\":\"rpc-checksum\","
    <> "\"row_count\":1,"
    <> "\"rows\":[{"
    <> "\"card_name\":\"Counterspell\","
    <> "\"set_code\":\"2XM\","
    <> "\"collector_number\":\"49\","
    <> "\"quantity\":1"
    <> "}]"
    <> "}"
  let _ = service.handle_request(rpc_service, import_request, Nil, deps)

  let query_request = "GetLatestImportStatus:202:readable:{\"unit\":true}"
  let #(raw, _) = service.handle_request(rpc_service, query_request, Nil, deps)

  should.equal(raw.status_code, 200)
}

pub fn skir_query_error_invalid_projection_group_test() {
  let deps = fresh_dependencies()
  let rpc_service = setup.make_service()

  let request =
    "GetInventoryProjection:304:readable:{"
    <> "\"sort_by\":\"card_name\","
    <> "\"group_by\":\"location\""
    <> "}"

  let #(raw, _) = service.handle_request(rpc_service, request, Nil, deps)

  should.equal(raw.status_code, 400)
  should.equal(raw.data, "invalid group_by")
}

fn fresh_dependencies() -> composition.Dependencies {
  card_catalog_sqlite.reset_for_tests()
  collection_import_sqlite.reset_for_tests()
  inventory_planning_sqlite.reset_for_tests()
  settings_sqlite.reset_for_tests()

  composition.Dependencies(
    card_catalog_repository: card_catalog_sqlite.new(),
    collection_import_repository: collection_import_sqlite.new(),
    inventory_planning_repository: inventory_planning_sqlite.new(),
    settings_repository: settings_sqlite.new(),
  )
}

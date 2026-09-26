import collection/infrastructure/daos/collection_dao
import gleam/option.{Some}
import gleam/time/calendar
import insights/infrastructure/daos/insights_dao
import inventory_planning/infrastructure/daos/inventory_rules_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import portability/domain/export_document
import portability/driver/export_file
import portability/infrastructure/adapters/commands/import_data/adapter
import portability/infrastructure/adapters/queries/export_data/adapter as export_data_adapter
import support/test_db

fn a_date() -> calendar.Date {
  calendar.Date(2026, calendar.September, 25)
}

fn rendered_export() -> String {
  let export_ports = export_data_adapter.new()
  let assert Ok(entries) = export_ports.list_collection_entries()
  let assert Ok(target_sets) = export_ports.list_target_sets()
  let assert Ok(rules) = export_ports.list_rules()
  let assert Ok(bulk) = export_ports.get_bulk_spec()
  let assert Ok(placed) = export_ports.list_placed()
  export_file.render(export_document.new(
    a_date(),
    entries,
    export_document.InsightsSection(target_sets:),
    export_document.InventoryPlanningSection(rules:, bulk:, placed:),
  ))
}

/// The acceptance round trip (#117, widened by #119): export, import that
/// file back in, export again — the two exports agree byte for byte and
/// every section is unchanged, for every finish and the zhs/zht split a
/// lossy format couldn't carry, alongside the target sets, rules, bulk
/// spec, and placed ledger.
pub fn export_import_export_is_byte_identical_and_every_section_is_unchanged_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.upsert_cards([
      collection_dao.CardRow(
        set_code: "dmu",
        collector_number: "101",
        finish: "etched",
        language: "zhs",
        quantity: 3,
      ),
      collection_dao.CardRow(
        set_code: "mh2",
        collector_number: "17",
        finish: "foil",
        language: "zht",
        quantity: 2,
      ),
      collection_dao.CardRow(
        set_code: "dmu",
        collector_number: "2",
        finish: "nonfoil",
        language: "en",
        quantity: 1,
      ),
    ])
  let assert Ok(Nil) = insights_dao.mark("neo")
  let assert Ok(Nil) = insights_dao.mark("2xm")
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
        language: "zht",
        location: "Binder A",
        quantity: 2,
      ),
    ])
  let before_file = rendered_export()

  let assert Ok(document) = export_file.parse(before_file)
  let import_ports = adapter.new(fn(_) { Ok(Nil) })
  let assert Some(target_sets) = document.target_sets
  let assert Ok(Nil) = import_ports.replace_target_sets(target_sets)
  let assert Ok(Nil) =
    import_ports.replace_plan(document.rules, document.bulk, document.placed)
  let assert Ok(Nil) = import_ports.replace_collection(document.collection)

  let after_file = rendered_export()

  assert after_file == before_file
}

/// This adapter delegates the whole collection write, including the
/// injected notify_changed call, to import_collection's own handler — which
/// deliberately ignores that call's result (ADR 0011: a subscriber's own
/// failure must not fail a write that already committed). Pinning that here
/// guards this new call site against a future change accidentally
/// propagating it.
pub fn a_failing_change_notification_does_not_fail_the_import_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.upsert_cards([
      collection_dao.CardRow(
        set_code: "mh2",
        collector_number: "17",
        finish: "nonfoil",
        language: "en",
        quantity: 1,
      ),
    ])
  let assert Ok(document) = export_file.parse(rendered_export())

  let import_ports = adapter.new(fn(_) { Error("subscriber down") })

  assert import_ports.replace_collection(document.collection) == Ok(Nil)
}

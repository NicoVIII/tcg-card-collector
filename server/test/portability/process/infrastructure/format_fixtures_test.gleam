import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/time/calendar
import insights/infrastructure/daos/insights_dao
import inventory_planning/infrastructure/daos/bulk_spec_dao
import inventory_planning/infrastructure/daos/inventory_rules_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import portability/domain/export_document
import portability/driver/export_file
import portability/infrastructure/adapters/commands/import_data/adapter
import portability/infrastructure/adapters/queries/export_data/adapter as export_data_adapter
import simplifile
import support/test_db

/// The date baked into `current_fixture` — fixed and frozen along with it,
/// same reasoning as its rows.
fn fixture_exported_on() -> calendar.Date {
  calendar.Date(2026, calendar.September, 25)
}

/// One frozen fixture per format version (`test/portability/fixtures/`,
/// `server/test/AGENTS.md`) — a fixture is never edited, only added. This
/// constant names the one the byte-identical round-trip test below checks;
/// a format bump repoints it and leaves the old fixture's own import test
/// in place, unchanged (ADR 0020).
const current_fixture = "test/portability/fixtures/format_v1.json"

fn read_fixture(path: String) -> String {
  let assert Ok(content) = simplifile.read(path)
  content
}

fn sorted_collection(rows: List(collection_dao.CardRow)) -> String {
  rows
  |> list.map(fn(row) {
    row.set_code
    <> " "
    <> row.collector_number
    <> " "
    <> row.finish
    <> " "
    <> row.language
  })
  |> list.sort(string.compare)
  |> string.join("\n")
}

/// The whole-file guard #133 asked for: a real v0.2.0-shaped export,
/// checked in once and frozen, imported by the current build and checked
/// for lossless results — a later format change can then only break this
/// file by someone deliberately editing the frozen fixture. Also proves
/// what `docs/portability/export.schema.json` validates against
/// (`just portability-schema-check`) is exactly what this build produces.
pub fn format_v1_fixture_imports_every_section_exactly_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(document) = export_file.parse(read_fixture(current_fixture))
  assert document.rejected == []

  let import_ports = adapter.new(fn(_) { Ok(Nil) })
  let assert Some(target_sets) = document.target_sets
  let assert Ok(Nil) = import_ports.replace_target_sets(target_sets)
  let assert Ok(Nil) =
    import_ports.replace_plan(document.rules, document.bulk, document.placed)
  let assert Ok(Nil) = import_ports.replace_collection(document.collection)

  let assert Ok(collection) = collection_dao.list_cards()
  assert sorted_collection(collection)
    == sorted_collection([
      collection_dao.CardRow("dmu", "101", "etched", "zhs", 3),
      collection_dao.CardRow("dmu", "2", "nonfoil", "en", 4),
      collection_dao.CardRow("dsk", "017", "nonfoil", "de", 1),
      collection_dao.CardRow("dsk", "104a", "foil", "en", 6),
      collection_dao.CardRow("mh2", "17", "foil", "zht", 2),
    ])

  assert insights_dao.list() == Ok(["2xm", "neo"])

  assert inventory_rules_dao.list()
    == Ok([
      inventory_rules_dao.RuleRow(
        id: "imported-0",
        location_name: "Binder A",
        expression: "rarity >= rare and finish = foil",
        position: 0,
        selector: "first_per_printing",
        sort_keys: "color_identity,type,name",
      ),
      inventory_rules_dao.RuleRow(
        id: "imported-1",
        location_name: "{set_code} box",
        expression: "token = no",
        position: 1,
        selector: "all",
        sort_keys: "",
      ),
    ])

  assert bulk_spec_dao.get() == Ok(#("Bulk crate", "set_code,name"))

  assert placed_cards_dao.list()
    == Ok([
      placed_cards_dao.PlacedCardRow(
        "dsk",
        "104a",
        "foil",
        "en",
        "Box B / Row 1",
        4,
      ),
      placed_cards_dao.PlacedCardRow(
        "dsk",
        "104a",
        "foil",
        "en",
        "Box B / Row 2",
        2,
      ),
    ])
}

/// Ties the encoder to the fixture directly: importing the fixture and
/// re-exporting it (same date) reproduces it byte for byte. Only the
/// current format version's fixture is checked this way — an older,
/// still-supported fixture is exercised by its own import test above, not
/// by round-tripping, since a newer encoder is never expected to reproduce
/// an old file's bytes.
pub fn current_format_fixture_re_exports_byte_identically_test() {
  use _db <- test_db.with_temp_db()

  let fixture = read_fixture(current_fixture)
  let assert Ok(document) = export_file.parse(fixture)

  let import_ports = adapter.new(fn(_) { Ok(Nil) })
  let assert Some(target_sets) = document.target_sets
  let assert Ok(Nil) = import_ports.replace_target_sets(target_sets)
  let assert Ok(Nil) =
    import_ports.replace_plan(document.rules, document.bulk, document.placed)
  let assert Ok(Nil) = import_ports.replace_collection(document.collection)

  let export_ports = export_data_adapter.new()
  let assert Ok(entries) = export_ports.list_collection_entries()
  let assert Ok(exported_target_sets) = export_ports.list_target_sets()
  let assert Ok(rules) = export_ports.list_rules()
  let assert Ok(bulk) = export_ports.get_bulk_spec()
  let assert Ok(placed) = export_ports.list_placed()

  let rendered =
    export_file.render(export_document.new(
      fixture_exported_on(),
      entries,
      export_document.InsightsSection(target_sets: exported_target_sets),
      export_document.InventoryPlanningSection(rules:, bulk:, placed:),
    ))

  assert rendered == fixture
}

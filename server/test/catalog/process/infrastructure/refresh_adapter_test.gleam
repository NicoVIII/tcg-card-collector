import catalog/application/commands/refresh/handler
import catalog/infrastructure/adapters/commands/refresh/adapter
import catalog/infrastructure/clients/scryfall_client
import catalog/infrastructure/daos/catalog_dao
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import shared/infrastructure/stores/sqlite_store
import sqlight
import support/test_db

fn single_text_column_decoder() {
  use value <- decode.field(0, decode.string)
  decode.success(value)
}

fn query_single_text(sql: String) -> String {
  case sqlite_store.query(sql, [], single_text_column_decoder()) {
    Ok([value, ..]) -> value
    _ -> ""
  }
}

const fixture_dir = "test/catalog/process/infrastructure/fixtures"

const metadata_fixture = fixture_dir <> "/scryfall_metadata.json"

const bulk_fixture = fixture_dir <> "/scryfall_bulk_cards.json"

const enriched_bulk_fixture = fixture_dir
  <> "/scryfall_bulk_cards_enriched.json"

const sets_page1_fixture = fixture_dir <> "/scryfall_sets_page1.json"

const sets_page2_fixture = fixture_dir <> "/scryfall_sets_page2.json"

const fixture_updated_at = "2024-01-01T00:00:00.000Z"

// URL routing for fake downloaders:
// - "fixture.local/bulk"   → bulk cards fixture (the download_uri in metadata.json)
// - "fixture.local/sets"   → sets page 2 (next_page URL from page1 fixture)
// - "scryfall.com/sets"    → sets page 1 (the /sets endpoint the client calls)
// - anything else          → metadata fixture
fn route_url(url: String, bulk: String) -> String {
  case string.contains(url, "fixture.local/bulk") {
    True -> bulk
    False ->
      case string.contains(url, "fixture.local/sets") {
        True -> sets_page2_fixture
        False ->
          case string.contains(url, "scryfall.com/sets") {
            True -> sets_page1_fixture
            False -> metadata_fixture
          }
      }
  }
}

fn fake_downloader() -> scryfall_client.Downloader {
  scryfall_client.Downloader(download: fn(url) {
    Ok(route_url(url, bulk_fixture))
  })
}

fn enriched_downloader() -> scryfall_client.Downloader {
  scryfall_client.Downloader(download: fn(url) {
    Ok(route_url(url, enriched_bulk_fixture))
  })
}

pub fn import_succeeds_and_loads_cards_test() {
  use _db <- test_db.with_temp_db()

  // catalog_sync_metadata is empty: upstream is "" -> different from fixture's
  // updated_at -> import branch runs
  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)

  assert result == Ok(Nil)

  // 4 cards in the fixture but test-id-004 has rarity "mythical_rare" (unknown)
  // and must be skipped; only 3 valid cards should be persisted
  let cards = catalog_dao.list()
  assert list.length(cards) == 3

  // Metadata should reflect succeeded
  let status =
    query_single_text(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
  assert status == "succeeded"

  let stored_updated_at =
    query_single_text(
      "SELECT last_upstream_updated_at FROM catalog_sync_metadata WHERE id = 1;",
    )
  assert stored_updated_at == fixture_updated_at
}

// Exercises the enrichment projection end-to-end: jq extracts the new
// attributes (with multi-face/reversible fallbacks), bulk_load stores them, and
// get_by_keys reads them back.
pub fn import_populates_enrichment_attributes_test() {
  use _db <- test_db.with_temp_db()

  let port = adapter.new_with_downloader(enriched_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)
  assert result == Ok(Nil)

  let rows =
    catalog_dao.get_by_keys([#("grn", "173"), #("sld", "1000"), #("mh1", "42")])
  assert list.length(rows) == 3

  // Normal card: multicolor identity joined, type_line and released_at present.
  let assert Ok(guildmage) =
    list.find(rows, fn(row) { row.0 == "grn" && row.1 == "173" })
  assert guildmage.5 == "oracle-e1"
  assert guildmage.6 == "WU"
  assert guildmage.7 == "Creature — Human Wizard"
  assert guildmage.8 == "2018-10-05"

  // Reversible card: no top-level oracle_id/type_line/image_uris -> falls back
  // to card_faces[0].
  let assert Ok(reversible) =
    list.find(rows, fn(row) { row.0 == "sld" && row.1 == "1000" })
  assert reversible.3 == "https://cards.scryfall.io/small/enr-002-face.jpg"
  assert reversible.5 == "oracle-e2"
  assert reversible.6 == "G"
  assert reversible.7 == "Legendary Creature — Elf"

  // Colorless card: empty color_identity array joins to "".
  let assert Ok(colorless) =
    list.find(rows, fn(row) { row.0 == "mh1" && row.1 == "42" })
  assert colorless.6 == ""
  assert colorless.7 == "Artifact — Thopter"
}

fn query_set_codes() -> List(String) {
  let decoder = {
    use code <- decode.field(0, decode.string)
    decode.success(code)
  }
  sqlite_store.query(
    "SELECT set_code FROM catalog_sets ORDER BY set_code;",
    [],
    decoder,
  )
  |> result.unwrap([])
}

fn query_set_released_at(set_code: String) -> String {
  let decoder = {
    use released_at <- decode.field(0, decode.string)
    decode.success(released_at)
  }
  case
    sqlite_store.query(
      "SELECT released_at FROM catalog_sets WHERE set_code = ?;",
      [sqlight.text(set_code)],
      decoder,
    )
  {
    Ok([value, ..]) -> value
    _ -> ""
  }
}

// A full import populates catalog_sets with all sets from both fixture pages.
pub fn import_populates_catalog_sets_from_all_pages_test() {
  use _db <- test_db.with_temp_db()

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)
  assert result == Ok(Nil)

  // page1 has "lea" + "grn"; page2 has "m11" → all three should be present
  let codes = query_set_codes()
  assert list.contains(codes, "lea")
  assert list.contains(codes, "grn")
  assert list.contains(codes, "m11")
}

// A null or absent released_at in the Scryfall response is stored as ''
// (Scryfall may omit nullable keys instead of sending null).
pub fn null_released_at_stored_as_empty_string_test() {
  use _db <- test_db.with_temp_db()

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)
  assert result == Ok(Nil)

  // "grn" in page1 has "released_at": null → stored as ''
  assert query_set_released_at("grn") == ""
  // "fut" in page2 has no released_at key at all → still imported, stored as ''
  // (query_set_released_at alone can't tell "empty" from "missing row")
  assert list.contains(query_set_codes(), "fut")
  assert query_set_released_at("fut") == ""
  // "lea" in page1 has a real date
  assert query_set_released_at("lea") == "1993-08-05"
}

// replace_sets is idempotent: a second import replaces stale rows entirely.
pub fn import_replaces_stale_catalog_sets_test() {
  use _db <- test_db.with_temp_db()

  // Seed a stale set not present in any fixture
  let assert Ok(Nil) =
    sqlite_store.exec(
      "INSERT INTO catalog_sets (set_code, name, released_at, card_count, icon_svg_uri) VALUES (?, ?, ?, ?, ?);",
      [
        sqlight.text("stale"),
        sqlight.text("Stale Set"),
        sqlight.text("2001-01-01"),
        sqlight.int(0),
        sqlight.text(""),
      ],
    )

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)
  assert result == Ok(Nil)

  // Stale set is gone; fixture sets are present
  let codes = query_set_codes()
  assert !list.contains(codes, "stale")
  assert list.contains(codes, "lea")
}

// The skip path (upstream unchanged) does not touch catalog_sets.
pub fn unchanged_upstream_marks_skipped_test() {
  use _db <- test_db.with_temp_db()

  // Seed: probe is due (>1 day ago) but upstream already matches the fixture
  let assert Ok(Nil) =
    sqlite_store.exec(
      "INSERT INTO catalog_sync_metadata "
        <> "(id, last_probe_at, last_upstream_updated_at, last_refresh_status, updated_at) "
        <> "VALUES (1, datetime('now','-2 day'), ?, 'succeeded', CURRENT_TIMESTAMP);",
      [sqlight.text(fixture_updated_at)],
    )

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)

  assert result == Ok(Nil)

  // No cards should have been imported
  assert catalog_dao.list() == []

  // Metadata should be skipped
  let status =
    query_single_text(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
  assert status == "skipped"
}

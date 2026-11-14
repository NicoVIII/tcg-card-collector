import card_catalog/application/commands/refresh/handler
import card_catalog/infrastructure/adapters/commands/refresh/adapter
import card_catalog/infrastructure/clients/scryfall_client
import card_catalog/infrastructure/daos/catalog_dao
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import shared/infrastructure/os_runtime
import shared/infrastructure/shell
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

const fixture_dir = "test/card_catalog/process/infrastructure/fixtures"

const metadata_fixture = fixture_dir <> "/scryfall_metadata.json"

const bulk_fixture = fixture_dir <> "/scryfall_bulk_cards.jsonl"

const enriched_bulk_fixture = fixture_dir
  <> "/scryfall_bulk_cards_enriched.jsonl"

const sets_page1_fixture = fixture_dir <> "/scryfall_sets_page1.json"

const sets_page2_fixture = fixture_dir <> "/scryfall_sets_page2.json"

const mtgjson_fixture = fixture_dir <> "/mtgjson_set_list.json"

const mtgjson_malformed_fixture = fixture_dir
  <> "/mtgjson_set_list_malformed.json"

const fixture_updated_at = "2024-01-01T00:00:00.000Z"

// URL routing for fake downloaders:
// - "fixture.local/bulk"   → bulk cards fixture (the jsonl_download_uri in metadata.json)
// - "fixture.local/sets"   → sets page 2 (next_page URL from page1 fixture)
// - "scryfall.com/sets"    → sets page 1 (the /sets endpoint the client calls)
// - "mtgjson.com"          → MTGJSON SetList fixture
// - anything else          → metadata fixture
fn route_url(url: String, bulk: String) -> String {
  case string.contains(url, "fixture.local/bulk") {
    True -> bulk
    False -> route_non_bulk_url(url)
  }
}

fn route_non_bulk_url(url: String) -> String {
  let routes = [
    #("mtgjson.com", mtgjson_fixture),
    #("fixture.local/sets", sets_page2_fixture),
    #("scryfall.com/sets", sets_page1_fixture),
  ]
  case list.find(routes, fn(route) { string.contains(url, route.0) }) {
    Ok(#(_, fixture)) -> fixture
    Error(Nil) -> metadata_fixture
  }
}

// Scryfall serves the bulk file gzipped; fixtures stay plain JSON Lines so
// they remain reviewable, and are compressed into a temp path on download.
fn gzipped_copy(fixture: String) -> Result(String, String) {
  let path =
    os_runtime.getenv_or("TMPDIR", "/tmp")
    <> "/tcg-test-bulk-"
    <> string.replace(fixture, "/", "_")
    <> ".gz"
  shell.run("gzip -c < " <> shell.quote(fixture) <> " > " <> shell.quote(path))
  |> result.replace(path)
}

fn downloader_for(bulk: String) -> scryfall_client.Downloader {
  scryfall_client.Downloader(download: fn(url) {
    case route_url(url, bulk) {
      path if path == bulk -> gzipped_copy(bulk)
      path -> Ok(path)
    }
  })
}

fn fake_downloader() -> scryfall_client.Downloader {
  downloader_for(bulk_fixture)
}

fn enriched_downloader() -> scryfall_client.Downloader {
  downloader_for(enriched_bulk_fixture)
}

// The fake downloader, with the MTGJSON request answered by `mtgjson`.
fn downloader_with_mtgjson(
  mtgjson: Result(String, String),
) -> scryfall_client.Downloader {
  let base = fake_downloader()
  scryfall_client.Downloader(download: fn(url) {
    case string.contains(url, "mtgjson.com") {
      True -> mtgjson
      False -> base.download(url)
    }
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
  let assert Ok(cards) = catalog_dao.list(option.None, option.None)
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

  let assert Ok(rows) =
    catalog_dao.get_by_keys([
      #("grn", "173"),
      #("sld", "1000"),
      #("mh1", "42"),
      #("mh1", "43"),
      #("sld", "1001"),
    ])
  assert list.length(rows) == 5

  // Normal card: multicolor identity joined, type_line, released_at and cmc
  // present.
  let assert Ok(guildmage) =
    list.find(rows, fn(row) {
      row.set_code == "grn" && row.collector_number == "173"
    })
  assert guildmage.oracle_id == "oracle-e1"
  assert guildmage.color_identity == "WU"
  assert guildmage.type_line == "Creature — Human Wizard"
  assert guildmage.released_at == "2018-10-05"
  assert guildmage.cmc == option.Some(2.0)
  assert guildmage.layout == option.Some("normal")

  // Reversible card: no top-level oracle_id/type_line/image_uris/cmc -> falls
  // back to card_faces[0] for all of them, including a fractional cmc.
  let assert Ok(reversible) =
    list.find(rows, fn(row) {
      row.set_code == "sld" && row.collector_number == "1000"
    })
  assert reversible.image_uri
    == "https://cards.scryfall.io/small/enr-002-face.jpg"
  assert reversible.oracle_id == "oracle-e2"
  assert reversible.color_identity == "G"
  assert reversible.type_line == "Legendary Creature — Elf"
  assert reversible.cmc == option.Some(0.5)
  assert reversible.layout == option.Some("reversible_card")

  // Colorless card: empty color_identity array joins to "". cmc: 0 (a real
  // zero-cost card) must survive jq's `//` and the CSV round trip, not read
  // back as unknown.
  let assert Ok(colorless) =
    list.find(rows, fn(row) {
      row.set_code == "mh1" && row.collector_number == "42"
    })
  assert colorless.color_identity == ""
  assert colorless.type_line == "Artifact — Thopter"
  assert colorless.cmc == option.Some(0.0)

  // No top-level cmc and no card_faces at all -> unknown, distinct from 0.
  // No layout key at all either -> jq's `// ""` fallback -> None, same gap
  // handling as every other absent enrichment field.
  let assert Ok(no_cmc) =
    list.find(rows, fn(row) {
      row.set_code == "mh1" && row.collector_number == "43"
    })
  assert no_cmc.cmc == option.None
  assert no_cmc.layout == option.None

  // A token layout round-trips through jq/CSV/bulk_load like any other
  // layout string.
  let assert Ok(token) =
    list.find(rows, fn(row) {
      row.set_code == "sld" && row.collector_number == "1001"
    })
  assert token.layout == option.Some("token")
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

// Reads parent_set_code, mapping a NULL (root set) to "" so the caller can't
// tell "no parent" from "no row" — matching how absence is treated.
fn query_set_parent(set_code: String) -> String {
  let decoder = {
    use parent <- decode.field(0, decode.optional(decode.string))
    decode.success(parent)
  }
  case
    sqlite_store.query(
      "SELECT parent_set_code FROM catalog_sets WHERE set_code = ?;",
      [sqlight.text(set_code)],
      decoder,
    )
  {
    Ok([option.Some(value), ..]) -> value
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

// A child set's parent_set_code is stored; a null or absent one becomes NULL
// (read back as "").
pub fn parent_set_code_stored_test() {
  use _db <- test_db.with_temp_db()

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)
  assert result == Ok(Nil)

  // "tgrn" in page1 declares "parent_set_code": "grn"
  assert query_set_parent("tgrn") == "grn"
  // "lea" has "parent_set_code": null → stored NULL
  assert query_set_parent("lea") == ""
  // "grn" omits the key entirely → stored NULL
  assert query_set_parent("grn") == ""
}

fn query_set_official_size(set_code: String) -> #(option.Option(Int), String) {
  let decoder = {
    use size <- decode.field(0, decode.optional(decode.int))
    use source <- decode.field(1, decode.optional(decode.string))
    decode.success(#(size, option.unwrap(source, "")))
  }
  case
    sqlite_store.query(
      "SELECT official_size, official_size_source FROM catalog_sets WHERE set_code = ?;",
      [sqlight.text(set_code)],
      decoder,
    )
  {
    Ok([row, ..]) -> row
    _ -> #(option.None, "no row")
  }
}

// ADR 0025's precedence, end to end through both upstream fixtures.
pub fn import_resolves_official_set_sizes_test() {
  use _db <- test_db.with_temp_db()

  let port = adapter.new_with_downloader(fake_downloader())
  assert handler.execute(handler.RefreshCatalogCommand, port) == Ok(Nil)

  // Scryfall says 295, MTGJSON 290: Scryfall wins.
  assert query_set_official_size("lea") == #(option.Some(295), "printed_size")
  // No printed_size; MTGJSON's uppercase "GRN" matches.
  assert query_set_official_size("grn") == #(option.Some(259), "base_set_size")
  // Token set with neither: its card_count.
  assert query_set_official_size("tgrn")
    == #(option.Some(20), "token_card_count")
  // MTGJSON's 0 means unknown, not an empty set.
  assert query_set_official_size("m11") == #(option.None, "")
  // In neither source.
  assert query_set_official_size("fut") == #(option.None, "")
}

// ADR 0025: an MTGJSON failure fails the sets import, names MTGJSON, and
// leaves the previously stored sets in place.
pub fn mtgjson_failure_fails_refresh_and_keeps_sets_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    sqlite_store.exec(
      "INSERT INTO catalog_sets (set_code, name, released_at, card_count, icon_svg_uri) VALUES ('old', 'Old Set', '', 0, '');",
      [],
    )

  let port =
    adapter.new_with_downloader(
      downloader_with_mtgjson(Error("curl: (6) Could not resolve host")),
    )
  let assert Error(error) = handler.execute(handler.RefreshCatalogCommand, port)

  assert string.contains(error.reason, "mtgjson")
  assert query_set_codes() == ["old"]
}

// A present but non-numeric baseSetSize is a format change, not "unknown".
pub fn malformed_mtgjson_size_fails_refresh_test() {
  use _db <- test_db.with_temp_db()

  let port =
    adapter.new_with_downloader(
      downloader_with_mtgjson(Ok(mtgjson_malformed_fixture)),
    )
  let assert Error(error) = handler.execute(handler.RefreshCatalogCommand, port)

  assert string.contains(error.reason, "mtgjson")
  assert string.contains(error.reason, "baseSetSize")
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
  assert catalog_dao.list(option.None, option.None) == Ok([])

  // Metadata should be skipped
  let status =
    query_single_text(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
  assert status == "skipped"
}

// Regression for #114: a migration that only nulls last_upstream_updated_at
// (0005, 0011, 0012, 0013, 0018's mistake) never forces a reload, because
// is_probe_due gates on last_probe_at first and returns before decide() ever
// reads the field the migration touched.
pub fn recent_probe_without_reset_imports_nothing_test() {
  use _db <- test_db.with_temp_db()

  // Seed: probed moments ago, so is_probe_due is False regardless of what
  // last_upstream_updated_at holds.
  let assert Ok(Nil) =
    sqlite_store.exec(
      "INSERT INTO catalog_sync_metadata "
        <> "(id, last_probe_at, last_upstream_updated_at, last_refresh_status, updated_at) "
        <> "VALUES (1, datetime('now'), ?, 'succeeded', CURRENT_TIMESTAMP);",
      [sqlight.text(fixture_updated_at)],
    )

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)

  assert result == Ok(Nil)
  assert catalog_dao.list(option.None, option.None) == Ok([])

  // Record is untouched: the handler never contacted upstream, so it wrote
  // nothing (see the "No save" comment in handler.execute).
  let status =
    query_single_text(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
  assert status == "succeeded"
}

// The documented reset (server/src/card_catalog/AGENTS.md): clearing the
// whole record forces a reload even when the last probe was moments ago,
// because load_refresh_record then returns None, which both is_probe_due
// and decide read as "contact upstream and import".
pub fn reset_request_reimports_despite_recent_probe_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    sqlite_store.exec(
      "INSERT INTO catalog_sync_metadata "
        <> "(id, last_probe_at, last_upstream_updated_at, last_refresh_status, updated_at) "
        <> "VALUES (1, datetime('now'), ?, 'succeeded', CURRENT_TIMESTAMP);",
      [sqlight.text(fixture_updated_at)],
    )

  // What a migration requesting a reset does.
  let assert Ok(Nil) =
    sqlite_store.exec("DELETE FROM catalog_sync_metadata;", [])

  let port = adapter.new_with_downloader(fake_downloader())
  let result = handler.execute(handler.RefreshCatalogCommand, port)

  assert result == Ok(Nil)
  let assert Ok(cards) = catalog_dao.list(option.None, option.None)
  assert list.length(cards) == 3

  let status =
    query_single_text(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
  assert status == "succeeded"
}

// Scryfall once dropped the link the client read; a missing jsonl_download_uri
// must fail the refresh with a reason naming it instead of importing nothing.
pub fn metadata_without_jsonl_uri_fails_naming_the_field_test() {
  use _db <- test_db.with_temp_db()

  let downloader =
    scryfall_client.Downloader(download: fn(_url) {
      Ok(fixture_dir <> "/scryfall_metadata_without_jsonl_uri.json")
    })
  let port = adapter.new_with_downloader(downloader)
  let assert Error(error) = handler.execute(handler.RefreshCatalogCommand, port)

  assert string.contains(error.reason, "jsonl_download_uri")
  assert catalog_dao.list(option.None, option.None) == Ok([])
}

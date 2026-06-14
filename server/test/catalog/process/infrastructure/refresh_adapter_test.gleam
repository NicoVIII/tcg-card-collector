import catalog/application/commands/refresh/handler
import catalog/infrastructure/adapters/commands/refresh/adapter
import catalog/infrastructure/stores/catalog_store
import gleam/list
import gleam/string
import infrastructure/stores/sqlite_store
import support/test_db

const fixture_dir = "test/catalog/process/infrastructure/fixtures"

const metadata_fixture = fixture_dir <> "/scryfall_metadata.json"

const bulk_fixture = fixture_dir <> "/scryfall_bulk_cards.json"

const fixture_updated_at = "2024-01-01T00:00:00.000Z"

// Returns the fixture metadata path for any URL except those containing
// "fixture.local" (the download_uri in scryfall_metadata.json), which get
// the bulk cards fixture.
fn fake_io() -> catalog_store.RefreshIO {
  catalog_store.RefreshIO(download: fn(url) {
    case string.contains(url, "fixture.local") {
      True -> Ok(bulk_fixture)
      False -> Ok(metadata_fixture)
    }
  })
}

pub fn import_succeeds_and_loads_cards_test() {
  use _db <- test_db.with_temp_db()

  // catalog_sync_metadata is empty: upstream is "" -> different from fixture's
  // updated_at -> import branch runs
  let port = adapter.new_with_io(fake_io())
  let result = handler.execute(handler.RefreshCatalogCommand, port)

  assert result == Ok(Nil)

  // 4 cards in the fixture but test-id-004 has rarity "mythical_rare" (unknown)
  // and must be skipped; only 3 valid cards should be persisted
  let cards = catalog_store.list()
  assert list.length(cards) == 3

  // Metadata should reflect succeeded
  let status =
    sqlite_store.query(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
    |> string.trim
  assert status == "succeeded"

  let stored_updated_at =
    sqlite_store.query(
      "SELECT last_upstream_updated_at FROM catalog_sync_metadata WHERE id = 1;",
    )
    |> string.trim
  assert stored_updated_at == fixture_updated_at
}

pub fn unchanged_upstream_marks_skipped_test() {
  use _db <- test_db.with_temp_db()

  // Seed: probe is due (>1 day ago) but upstream already matches the fixture
  sqlite_store.exec(
    "INSERT INTO catalog_sync_metadata "
    <> "(id, last_probe_at, last_upstream_updated_at, last_refresh_status, updated_at) "
    <> "VALUES (1, datetime('now','-2 day'), '"
    <> fixture_updated_at
    <> "', 'succeeded', CURRENT_TIMESTAMP);",
  )

  let port = adapter.new_with_io(fake_io())
  let result = handler.execute(handler.RefreshCatalogCommand, port)

  assert result == Ok(Nil)

  // No cards should have been imported
  assert catalog_store.list() == []

  // Metadata should be skipped
  let status =
    sqlite_store.query(
      "SELECT last_refresh_status FROM catalog_sync_metadata WHERE id = 1;",
    )
    |> string.trim
  assert status == "skipped"
}

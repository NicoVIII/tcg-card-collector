import catalog/application/commands/refresh/handler
import catalog/infrastructure/adapters/commands/refresh/adapter
import catalog/infrastructure/clients/scryfall_client
import catalog/infrastructure/daos/catalog_dao
import gleam/dynamic/decode
import gleam/list
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

const fixture_updated_at = "2024-01-01T00:00:00.000Z"

// Returns the fixture metadata path for any URL except those containing
// "fixture.local" (the download_uri in scryfall_metadata.json), which get
// the bulk cards fixture.
fn fake_downloader() -> scryfall_client.Downloader {
  scryfall_client.Downloader(download: fn(url) {
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

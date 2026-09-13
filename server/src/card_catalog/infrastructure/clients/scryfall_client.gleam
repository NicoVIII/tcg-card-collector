import card_catalog/domain/card_set
import card_catalog/infrastructure/clients/scryfall_mapper
import gleam/bool
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import shared/infrastructure/os_runtime
import shared/infrastructure/shell
import simplifile

pub type Downloader {
  Downloader(download: fn(String) -> Result(String, String))
}

const bulk_metadata_url = "https://api.scryfall.com/bulk-data/default_cards"

const sets_url = "https://api.scryfall.com/sets"

// Scryfall /sets is one page today; the loop cap guards against malformed
// responses producing infinite chains. No inter-request delay: the set list
// is tiny and runs strictly after the card bulk import consumed its download.
const page_cap = 50

fn log(message: String) -> Nil {
  io.println("[refresh] " <> message)
}

fn log_error(stage: String, detail: String) -> Nil {
  io.println("[refresh][error] " <> stage <> ": " <> detail)
}

// Logs a failed stage and simplifies its reason; the Ok path passes through.
fn or_fail(outcome: Result(a, String), stage: String) -> Result(a, String) {
  result.map_error(outcome, fn(reason) {
    let simplified = shell.simplify_error(reason)
    log_error(stage, simplified)
    simplified
  })
}

// Uses a single fixed temp path so nothing accumulates between runs.
// The path is overwritten on each download; concurrent refreshes are not expected.
pub fn live_downloader() -> Downloader {
  let tmp_dir = os_runtime.getenv_or("TMPDIR", "/tmp")
  let download_path = tmp_dir <> "/tcg-refresh-download"
  Downloader(download: fn(url) {
    let script =
      "set +e; curl -fsSL --compressed --connect-timeout 10 --max-time 480 "
      <> shell.quote(url)
      <> " -o "
      <> shell.quote(download_path)
      <> "; status=$?; printf '\\n__EXIT__:%s' \"$status\""
    let output = os_runtime.cmd("sh -c " <> shell.quote(script))
    case string.split(output, "__EXIT__:") {
      [_, status_raw] ->
        case string.trim(status_raw) {
          "0" -> Ok(download_path)
          _ -> Error(string.trim(output))
        }
      _ -> Error(string.trim(output))
    }
  })
}

// The jq output is "updated_at<TAB>download_uri"; the logged detail carries the
// offending text, the returned error stays short.
fn parse_metadata_tsv(output: String) -> Result(#(String, String), String) {
  let trimmed = string.trim(output)
  case string.split(trimmed, "\t") {
    [updated_at, download_uri] if updated_at != "" && download_uri != "" ->
      Ok(#(updated_at, download_uri))
    [_, _] -> {
      log_error(
        "metadata parse",
        "invalid metadata response from scryfall (empty fields in: "
          <> trimmed
          <> ")",
      )
      Error("invalid metadata response from scryfall")
    }
    _ -> {
      log_error(
        "metadata parse",
        "invalid metadata response from scryfall (unexpected tsv: "
          <> trimmed
          <> ")",
      )
      Error("invalid metadata response from scryfall")
    }
  }
}

pub fn fetch_metadata(io: Downloader) -> Result(#(String, String), String) {
  use path <- result.try(
    io.download(bulk_metadata_url) |> or_fail("metadata download"),
  )
  // Failing inside jq names the missing field; a null would otherwise surface
  // as an empty trailing column that shell.run's trim silently drops.
  let script =
    "jq -r 'if .updated_at and .jsonl_download_uri then [.updated_at, .jsonl_download_uri] | @tsv else error(\"missing updated_at or jsonl_download_uri\") end' < "
    <> shell.quote(path)
  use output <- result.try(shell.run(script) |> or_fail("metadata jq parse"))
  use #(updated_at, download_uri) <- result.try(parse_metadata_tsv(output))
  log("metadata ok: updated_at=" <> updated_at <> " uri=" <> download_uri)
  Ok(#(updated_at, download_uri))
}

fn fetch_sets_loop(
  io: Downloader,
  url: String,
  acc: List(card_set.CardSet),
  page: Int,
) -> Result(List(card_set.CardSet), String) {
  use <- bool.lazy_guard(page >= page_cap, fn() {
    log("sets: page cap reached")
    Ok(acc)
  })
  use path <- result.try(io.download(url) |> or_fail("sets download"))
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(err) {
      "failed to read sets page: " <> simplifile.describe_error(err)
    })
    |> or_fail("sets read"),
  )
  use #(sets, next_page) <- result.try(
    scryfall_mapper.parse_sets_page(content) |> or_fail("sets parse"),
  )
  let collected = list.append(acc, sets)
  case next_page {
    None -> Ok(collected)
    Some(next_url) -> fetch_sets_loop(io, next_url, collected, page + 1)
  }
}

pub fn fetch_sets(io: Downloader) -> Result(List(card_set.CardSet), String) {
  fetch_sets_loop(io, sets_url, [], 0)
}

pub fn download_cards(io: Downloader, uri: String) -> Result(String, String) {
  log("import: downloading " <> uri)
  io.download(uri) |> or_fail("import download")
}

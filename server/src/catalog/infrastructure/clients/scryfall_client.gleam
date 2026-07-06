import catalog/domain/card_set
import catalog/infrastructure/clients/scryfall_mapper
import gleam/io
import gleam/list
import gleam/option.{None, Some}
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

pub fn fetch_metadata(io: Downloader) -> Result(#(String, String), String) {
  case io.download(bulk_metadata_url) {
    Error(reason) -> {
      let simplified = shell.simplify_error(reason)
      log_error("metadata download", simplified)
      Error(simplified)
    }
    Ok(path) -> {
      let script =
        "jq -r '[.updated_at, .download_uri] | @tsv' < " <> shell.quote(path)
      case shell.run(script) {
        Error(output) -> {
          let simplified = shell.simplify_error(output)
          log_error("metadata jq parse", simplified)
          Error(simplified)
        }
        Ok(output) ->
          case string.split(string.trim(output), "\t") {
            [updated_at, download_uri] ->
              case updated_at != "" && download_uri != "" {
                True -> {
                  log(
                    "metadata ok: updated_at="
                    <> updated_at
                    <> " uri="
                    <> download_uri,
                  )
                  Ok(#(updated_at, download_uri))
                }
                False -> {
                  log_error(
                    "metadata parse",
                    "invalid metadata response from scryfall (empty fields in: "
                      <> string.trim(output)
                      <> ")",
                  )
                  Error("invalid metadata response from scryfall")
                }
              }
            _ -> {
              log_error(
                "metadata parse",
                "invalid metadata response from scryfall (unexpected tsv: "
                  <> string.trim(output)
                  <> ")",
              )
              Error("invalid metadata response from scryfall")
            }
          }
      }
    }
  }
}

pub fn fetch_sets(io: Downloader) -> Result(List(card_set.CardSet), String) {
  fetch_sets_loop(io, sets_url, [], 0)
}

fn fetch_sets_loop(
  io: Downloader,
  url: String,
  acc: List(card_set.CardSet),
  page: Int,
) -> Result(List(card_set.CardSet), String) {
  case page >= page_cap {
    True -> {
      log("sets: page cap reached")
      Ok(acc)
    }
    False ->
      case io.download(url) {
        Error(reason) -> {
          let simplified = shell.simplify_error(reason)
          log_error("sets download", simplified)
          Error(simplified)
        }
        Ok(path) ->
          case simplifile.read(path) {
            Error(err) -> {
              let msg = "failed to read sets page: " <> string.inspect(err)
              log_error("sets read", msg)
              Error(msg)
            }
            Ok(content) ->
              case scryfall_mapper.parse_sets_page(content) {
                Error(reason) -> {
                  log_error("sets parse", reason)
                  Error(reason)
                }
                Ok(#(sets, next_page)) ->
                  case next_page {
                    None -> Ok(list.append(acc, sets))
                    Some(next_url) ->
                      fetch_sets_loop(
                        io,
                        next_url,
                        list.append(acc, sets),
                        page + 1,
                      )
                  }
              }
          }
      }
  }
}

pub fn download_cards(io: Downloader, uri: String) -> Result(String, String) {
  log("import: downloading " <> uri)
  case io.download(uri) {
    Error(reason) -> {
      let simplified = shell.simplify_error(reason)
      log_error("import download", simplified)
      Error(simplified)
    }
    Ok(path) -> Ok(path)
  }
}

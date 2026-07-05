import gleam/bytes_tree
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import gleam/uri
import mist
import shared/driver/http/json_codec

// ── content_type ─────────────────────────────────────────────────────────────

pub fn content_type(path: String) -> String {
  let ext =
    string.split(path, ".")
    |> list.last
    |> result.unwrap("")
  case ext {
    "html" -> "text/html; charset=utf-8"
    "js" | "mjs" -> "application/javascript"
    "css" -> "text/css"
    "json" -> "application/json"
    "svg" -> "image/svg+xml"
    "png" -> "image/png"
    "jpg" | "jpeg" -> "image/jpeg"
    "webp" -> "image/webp"
    "gif" -> "image/gif"
    "ico" -> "image/x-icon"
    "woff" -> "font/woff"
    "woff2" -> "font/woff2"
    "txt" -> "text/plain; charset=utf-8"
    "map" -> "application/json"
    "wasm" -> "application/wasm"
    _ -> "application/octet-stream"
  }
}

// ── resolve_path ─────────────────────────────────────────────────────────────

pub fn resolve_path(root: String, request_path: String) -> Result(String, Nil) {
  use decoded <- result.try(
    string.split(request_path, "/")
    |> list.try_map(uri.percent_decode),
  )
  let filtered = list.filter(decoded, fn(seg) { seg != "" && seg != "." })
  let safe =
    list.all(filtered, fn(seg) {
      seg != ".."
      && !string.contains(seg, "\\")
      && !string.contains(seg, "\u{0}")
    })
  case safe {
    False -> Error(Nil)
    True ->
      case filtered {
        [] -> Ok(root <> "/index.html")
        segs -> Ok(root <> "/" <> string.join(segs, "/"))
      }
  }
}

// ── serve ────────────────────────────────────────────────────────────────────

pub fn serve(
  root: String,
  request_path: String,
) -> Response(mist.ResponseData) {
  case resolve_path(root, request_path) {
    Error(Nil) -> not_found()
    Ok(path) ->
      case try_file(path) {
        Ok(resp) -> resp
        Error(Nil) -> spa_fallback(root)
      }
  }
}

// ── private ───────────────────────────────────────────────────────────────────

fn not_found() -> Response(mist.ResponseData) {
  response.new(404)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(
    json_codec.encode_error("not found")
    |> bytes_tree.from_string
    |> mist.Bytes,
  )
}

fn try_file(path: String) -> Result(Response(mist.ResponseData), Nil) {
  case mist.send_file(path, offset: 0, limit: None) {
    Error(_) -> Error(Nil)
    Ok(body) ->
      Ok(
        response.new(200)
        |> response.set_header("content-type", content_type(path))
        |> response.set_body(body),
      )
  }
}

fn spa_fallback(root: String) -> Response(mist.ResponseData) {
  case try_file(root <> "/index.html") {
    Ok(resp) -> resp
    Error(Nil) -> not_found()
  }
}

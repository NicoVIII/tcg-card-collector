import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import mist
import skir/setup
import skir_client/service

pub fn handle_request(
  req: Request(mist.Connection),
  server_name: setup.ServerName,
) -> Response(mist.ResponseData) {
  case req.method, path_without_query(req.path) {
    Get, "/api/skir" -> handle_get(req, server_name)
    Post, "/api/skir" -> handle_post(req, server_name)
    _, "/api/skir" ->
      text_response(405, "text/plain; charset=utf-8", "method not allowed")
    _, _ -> text_response(404, "text/plain; charset=utf-8", "not found")
  }
}

fn handle_get(
  req: Request(mist.Connection),
  server_name: setup.ServerName,
) -> Response(mist.ResponseData) {
  let raw_query = option.unwrap(req.query, "")
  let decoded_query = result.unwrap(uri.percent_decode(raw_query), raw_query)
  let raw =
    process.call_forever(process.named_subject(server_name), setup.HandleRpc(
      decoded_query,
      _,
    ))

  from_raw_response(raw)
}

fn handle_post(
  req: Request(mist.Connection),
  server_name: setup.ServerName,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, max_body_limit: 10_000_000) {
    Error(_) ->
      text_response(
        400,
        "text/plain; charset=utf-8",
        "bad request: failed to read request body",
      )
    Ok(req_with_body) ->
      case bit_array.to_string(req_with_body.body) {
        Error(_) ->
          text_response(
            400,
            "text/plain; charset=utf-8",
            "bad request: body is not valid UTF-8",
          )
        Ok(body_str) ->
          process.call_forever(
            process.named_subject(server_name),
            setup.HandleRpc(body_str, _),
          )
          |> from_raw_response
      }
  }
}

fn from_raw_response(raw: service.RawResponse) -> Response(mist.ResponseData) {
  response.new(raw.status_code)
  |> response.set_header("content-type", raw.content_type)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(raw.data)))
}

fn text_response(
  status: Int,
  content_type: String,
  body: String,
) -> Response(mist.ResponseData) {
  response.new(status)
  |> response.set_header("content-type", content_type)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn path_without_query(path: String) -> String {
  case string.split(path, "?") {
    [p, ..] -> p
    _ -> path
  }
}

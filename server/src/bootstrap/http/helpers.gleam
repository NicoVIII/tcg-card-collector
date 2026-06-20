import bootstrap/http/json_codec
import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/string
import mist

pub fn json_response(status: Int, body: String) -> Response(mist.ResponseData) {
  response.new(status)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(
    body
    |> bytes_tree.from_string
    |> mist.Bytes,
  )
}

pub fn with_json_body(
  req: Request(mist.Connection),
  next: fn(String) -> Response(mist.ResponseData),
) -> Response(mist.ResponseData) {
  case mist.read_body(req, max_body_limit: 1_000_000) {
    Error(_) ->
      json_response(400, json_codec.encode_error("could not read body"))
    Ok(req_with_body) ->
      case bit_array.to_string(req_with_body.body) {
        Error(_) ->
          json_response(400, json_codec.encode_error("body is not valid utf-8"))
        Ok(body_string) -> next(body_string)
      }
  }
}

pub fn query_param(
  req: Request(mist.Connection),
  key: String,
) -> Result(String, Nil) {
  case string.split(req.path, "?") {
    [_, qs, ..] ->
      qs
      |> string.split("&")
      |> list.find_map(fn(pair) {
        case string.split(pair, "=") {
          [k, v] if k == key -> Ok(v)
          _ -> Error(Nil)
        }
      })
    _ -> Error(Nil)
  }
}

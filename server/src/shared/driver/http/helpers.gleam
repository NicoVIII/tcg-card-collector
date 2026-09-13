import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import mist
import shared/driver/http/json_codec

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

/// Query ports fail with a bare reason, which always surfaces as a 500.
pub fn query_response(
  result: Result(a, String),
  encode: fn(a) -> String,
) -> Response(mist.ResponseData) {
  case result {
    Ok(value) -> json_response(200, encode(value))
    Error(reason) -> json_response(500, json_codec.encode_error(reason))
  }
}

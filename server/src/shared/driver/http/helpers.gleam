import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{type Option}
import mist
import shared/driver/http/json_codec
import shared/driver/presented_error.{type PresentedError, BadRequest, Internal}

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

/// A malformed query string (bad percent-encoding) reads as no params, the
/// same as an absent one — there's nothing more specific to tell the caller.
pub fn query_param(
  req: Request(mist.Connection),
  key: String,
) -> Option(String) {
  case request.get_query(req) {
    Ok(params) -> list.key_find(params, key) |> option.from_result
    Error(_) -> option.None
  }
}

pub fn error_response(error: PresentedError) -> Response(mist.ResponseData) {
  let status = case error.class {
    BadRequest -> 400
    Internal -> 500
  }
  json_response(status, json_codec.encode_error(error.message))
}

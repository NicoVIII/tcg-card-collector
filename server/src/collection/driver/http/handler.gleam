import collection/application/handler as collection_handler
import collection/driver/http/json_codec as collection_codec
import composition.{type Dependencies}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import http/helpers
import http/json_codec
import mist

pub fn handle_import_collection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case collection_codec.decode_import_collection_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      collection_handler.import_collection(
        deps.import_collection_port,
        b.import_run_id,
        b.source_name,
        b.source_checksum,
        b.row_count,
        [],
      )
      helpers.json_response(202, json_codec.encode_ok("accepted"))
    }
  }
}

pub fn handle_latest_import_status(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    collection_handler.get_latest_import_status(deps.latest_import_status_port)
  {
    collection_handler.ImportStatusFound(run) ->
      helpers.json_response(
        200,
        collection_codec.encode_import_status_found(run),
      )
    collection_handler.ImportStatusNotFound ->
      helpers.json_response(
        200,
        collection_codec.encode_import_status_not_found(),
      )
  }
}

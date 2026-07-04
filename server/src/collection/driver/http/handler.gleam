import collection/application/commands/import_collection/handler as import_collection_handler
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/handler as latest_status_handler
import collection/domain/import_mode
import collection/driver/dependencies.{type Dependencies}
import collection/driver/http/json_codec as collection_codec
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{None, Some}
import mist
import shared/driver/http/helpers
import shared/driver/http/json_codec

pub fn handle_import_collection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case collection_codec.decode_import_collection_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case import_mode.parse(b.mode) {
        Error(Nil) ->
          helpers.json_response(400, json_codec.encode_error("invalid mode"))
        Ok(mode) ->
          case
            import_collection_handler.execute(
              import_collection_handler.ImportCollectionCommand(
                import_run_id: b.import_run_id,
                source_name: b.source_name,
                row_count: b.row_count,
                rows: list.map(b.rows, map_import_collection_row),
                mode: mode,
              ),
              deps.import_collection_ports,
            )
          {
            Ok(_) ->
              helpers.json_response(200, json_codec.encode_ok("accepted"))
            Error(import_collection_ports.RowCountMismatch) ->
              helpers.json_response(
                422,
                json_codec.encode_error("row count mismatch"),
              )
            Error(import_collection_ports.PersistenceFailed(reason)) ->
              helpers.json_response(500, json_codec.encode_error(reason))
          }
      }
  }
}

fn map_import_collection_row(
  row: collection_codec.ImportCollectionRow,
) -> import_collection_ports.ImportCollectionRow {
  import_collection_ports.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

pub fn handle_latest_import_status(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    latest_status_handler.execute(
      latest_status_handler.LatestImportStatusQuery,
      deps.latest_import_status_port,
    )
  {
    Ok(Some(run)) ->
      helpers.json_response(
        200,
        collection_codec.encode_import_status_found(run),
      )
    Ok(None) ->
      helpers.json_response(
        200,
        collection_codec.encode_import_status_not_found(),
      )
    Error(reason) -> helpers.json_response(500, json_codec.encode_error(reason))
  }
}

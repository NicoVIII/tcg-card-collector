import collection/application/commands/add_cards/handler as add_cards_handler
import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/handler as import_collection_handler
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/handler as latest_status_handler
import collection/driver/dependencies.{type Dependencies}
import collection/driver/http/json_codec as collection_codec
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{None, Some}
import mist
import shared/domain/non_empty_string
import shared/driver/http/helpers
import shared/driver/http/json_codec

fn map_import_collection_row(
  row: collection_codec.ImportCollectionRow,
) -> import_collection_ports.ImportCollectionRow {
  import_collection_ports.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

pub fn handle_import_collection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case collection_codec.decode_import_collection_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        non_empty_string.new(b.import_run_id),
        non_empty_string.new(b.source_name)
      {
        Ok(import_run_id), Ok(source_name) ->
          case
            import_collection_handler.execute(
              import_collection_handler.ImportCollectionCommand(
                import_run_id: import_run_id,
                source_name: source_name,
                row_count: b.row_count,
                rows: list.map(b.rows, map_import_collection_row),
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
        _, _ ->
          helpers.json_response(
            400,
            json_codec.encode_error(
              "import_run_id and source_name must not be empty",
            ),
          )
      }
  }
}

fn map_add_cards_row(
  row: collection_codec.AddCardsRow,
) -> add_cards_ports.AddCardsRow {
  add_cards_ports.AddCardsRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

pub fn handle_add_cards(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case collection_codec.decode_add_cards_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case non_empty_string.new(b.add_run_id) {
        Ok(add_run_id) ->
          case
            add_cards_handler.execute(
              add_cards_handler.AddCardsCommand(
                add_run_id: add_run_id,
                rows: list.map(b.rows, map_add_cards_row),
              ),
              deps.add_cards_ports,
            )
          {
            Ok(_) -> helpers.json_response(200, json_codec.encode_ok("added"))
            Error(add_cards_ports.InvalidRows) ->
              helpers.json_response(
                422,
                json_codec.encode_error("invalid rows"),
              )
            Error(add_cards_ports.PersistenceFailed(reason)) ->
              helpers.json_response(500, json_codec.encode_error(reason))
          }
        Error(Nil) ->
          helpers.json_response(
            400,
            json_codec.encode_error("add_run_id must not be empty"),
          )
      }
  }
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

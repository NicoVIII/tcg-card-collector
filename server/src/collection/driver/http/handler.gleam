import collection/application/commands/add_cards/handler as add_cards_handler
import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/remove_cards/handler as remove_cards_handler
import collection/application/commands/remove_cards/ports as remove_cards_ports
import collection/application/queries/list_cards/handler as list_collection_cards_handler
import collection/driver/dependencies.{type Dependencies}
import collection/driver/error_presentation
import collection/driver/http/json_codec as collection_codec
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import mist
import shared/driver/http/helpers
import shared/driver/http/json_codec
import shared/driver/search_filter

fn map_add_cards_row(
  row: collection_codec.AddCardsRow,
) -> add_cards_ports.AddCardsRow {
  add_cards_ports.AddCardsRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: row.finish,
    language: row.language,
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
      case
        add_cards_handler.execute(
          add_cards_handler.AddCardsCommand(rows: list.map(
            b.rows,
            map_add_cards_row,
          )),
          deps.add_cards_port,
        )
      {
        Ok(_) -> helpers.json_response(200, json_codec.encode_ok("added"))
        Error(add_cards_ports.InvalidRows) ->
          helpers.json_response(422, json_codec.encode_error("invalid rows"))
        Error(add_cards_ports.PersistenceFailed(reason)) ->
          helpers.json_response(500, json_codec.encode_error(reason))
      }
  }
}

fn map_remove_cards_row(
  row: collection_codec.RemoveCardsRow,
) -> remove_cards_ports.RemoveCardsRow {
  remove_cards_ports.RemoveCardsRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: row.finish,
    language: row.language,
    quantity: row.quantity,
  )
}

pub fn handle_remove_cards(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case collection_codec.decode_remove_cards_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        remove_cards_handler.execute(
          remove_cards_handler.RemoveCardsCommand(rows: list.map(
            b.rows,
            map_remove_cards_row,
          )),
          deps.remove_cards_ports,
        )
      {
        Ok(_) -> helpers.json_response(200, json_codec.encode_ok("decremented"))
        Error(remove_cards_ports.InvalidRows) ->
          helpers.json_response(422, json_codec.encode_error("invalid rows"))
        Error(remove_cards_ports.PersistenceFailed(reason)) ->
          helpers.error_response(error_presentation.remove_cards(reason))
      }
  }
}

fn respond_with_collection_page(
  req: Request(mist.Connection),
  deps: Dependencies,
  offset: Int,
  limit: Int,
) -> Response(mist.ResponseData) {
  list_collection_cards_handler.execute(
    list_collection_cards_handler.ListCollectionCardsQuery(
      offset:,
      limit:,
      name: search_filter.parse_name(helpers.query_param(req, "name")),
      set_code: search_filter.parse_set_code(helpers.query_param(req, "set")),
    ),
    deps.list_collection_cards_ports,
  )
  |> helpers.query_response(collection_codec.encode_collection_card_page(
    _,
    offset,
    limit,
  ))
}

pub fn handle_list_collection_cards(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case helpers.int_query_param(req, "offset", 0) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(offset) ->
      case helpers.int_query_param(req, "limit", 0) {
        Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
        Ok(limit) -> respond_with_collection_page(req, deps, offset, limit)
      }
  }
}

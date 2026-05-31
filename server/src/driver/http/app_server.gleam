import composition.{type Dependencies}
import driver/http/json_codec
import driver/skir/card_catalog_handler
import driver/skir/collection_import_handler
import driver/skir/inventory_planning_handler
import driver/skir/router as skir_router
import driver/skir/settings_handler
import driver/skir/setup as skir_setup
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import mist

pub fn start(deps: Dependencies) -> Nil {
  let port = read_port()
  let rpc_service = skir_setup.make_service()
  let server_name = process.new_name("skir_rpc_server")

  let _server_pid =
    process.spawn(fn() {
      skir_setup.start_server_loop(
        server_name,
        skir_setup.ServerState(service: rpc_service, context: deps),
      )
    })

  let handler = fn(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
    handle_request(req, deps, server_name)
  }

  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start

  process.sleep_forever()
}

fn read_port() -> Int {
  get_env("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}

fn handle_request(
  req: Request(mist.Connection),
  deps: Dependencies,
  server_name: skir_setup.ServerName,
) -> Response(mist.ResponseData) {
  let path = path_without_query(req.path)

  case req.method, path {
    Get, "/api/catalog/cards" -> handle_list_catalog_cards(deps)
    Post, "/api/catalog/refresh" -> handle_refresh_catalog(deps)
    Post, "/api/import" -> handle_import_collection(req, deps)
    Get, "/api/import/latest" -> handle_latest_import_status(deps)
    Get, "/api/inventory/rules" -> handle_list_inventory_rules(deps)
    Put, "/api/inventory/rules" -> handle_upsert_inventory_rule(req, deps)
    Delete, "/api/inventory/rules" -> handle_delete_inventory_rule(req, deps)
    Get, "/api/inventory/projection" -> handle_inventory_projection(req, deps)
    Get, "/api/settings" -> handle_get_settings(deps)
    Put, "/api/settings" -> handle_update_settings(req, deps)
    Get, "/api/skir" | Post, "/api/skir" ->
      skir_router.handle_request(req, server_name)
    _, _ -> json_response(404, json_codec.encode_error("not found"))
  }
}

// ---- Card catalog -----------------------------------------------------------

fn handle_list_catalog_cards(deps: Dependencies) -> Response(mist.ResponseData) {
  let cards =
    card_catalog_handler.list_catalog_cards(deps.card_catalog_repository)
  json_response(200, json_codec.encode_catalog_cards(cards))
}

fn handle_refresh_catalog(deps: Dependencies) -> Response(mist.ResponseData) {
  case card_catalog_handler.refresh_catalog(deps.card_catalog_repository) {
    card_catalog_handler.Success ->
      json_response(200, json_codec.encode_ok("catalog refreshed"))
    card_catalog_handler.Failed ->
      json_response(503, json_codec.encode_error("catalog refresh failed"))
  }
}

// ---- Collection import ------------------------------------------------------

fn handle_import_collection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- with_json_body(req)
  case json_codec.decode_import_collection_body(body) {
    Error(msg) -> json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      collection_import_handler.import_collection(
        deps.collection_import_repository,
        collection_import_handler.ImportCollectionRequest(
          import_run_id: b.import_run_id,
          source_name: b.source_name,
          source_checksum: b.source_checksum,
          row_count: b.row_count,
          rows: [],
        ),
      )
      json_response(202, json_codec.encode_ok("accepted"))
    }
  }
}

fn handle_latest_import_status(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    collection_import_handler.get_latest_import_status(
      deps.collection_import_repository,
    )
  {
    collection_import_handler.ImportStatusFound(run) ->
      json_response(200, json_codec.encode_import_status_found(run))
    collection_import_handler.ImportStatusNotFound ->
      json_response(200, json_codec.encode_import_status_not_found())
  }
}

// ---- Inventory planning -----------------------------------------------------

fn handle_list_inventory_rules(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let rules =
    inventory_planning_handler.list_inventory_rules(
      deps.inventory_planning_repository,
    )
  json_response(200, json_codec.encode_inventory_rules(rules))
}

fn handle_upsert_inventory_rule(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- with_json_body(req)
  case json_codec.decode_upsert_rule_body(body) {
    Error(msg) -> json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      case
        inventory_planning_handler.upsert_inventory_rule(
          deps.inventory_planning_repository,
          inventory_planning_handler.UpsertInventoryRuleRequest(
            id: b.id,
            location_name: b.location_name,
            expression: b.expression,
          ),
        )
      {
        Ok(_) -> json_response(200, json_codec.encode_ok("rule saved"))
        Error(inventory_planning_handler.InvalidRuleExpression) ->
          json_response(
            400,
            json_codec.encode_error("invalid inventory rule expression"),
          )
        Error(_) ->
          json_response(400, json_codec.encode_error("invalid inventory rule"))
      }
    }
  }
}

fn handle_delete_inventory_rule(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- with_json_body(req)
  case json_codec.decode_delete_rule_body(body) {
    Error(msg) -> json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      inventory_planning_handler.delete_inventory_rule(
        deps.inventory_planning_repository,
        inventory_planning_handler.DeleteInventoryRuleRequest(id: b.id),
      )
      json_response(200, json_codec.encode_ok("rule deleted"))
    }
  }
}

fn handle_inventory_projection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let sort_by = query_param(req, "sort_by") |> result.unwrap("card_name")
  let group_by = query_param(req, "group_by") |> result.unwrap("location_name")
  let rows_result =
    inventory_planning_handler.inventory_projection(
      deps.inventory_planning_repository,
      inventory_planning_handler.InventoryProjectionRequest(
        sort_by: sort_by,
        group_by: group_by,
      ),
    )

  case rows_result {
    Ok(rows) -> json_response(200, json_codec.encode_inventory_projection(rows))
    Error(inventory_planning_handler.InvalidSortBy) ->
      json_response(400, json_codec.encode_error("invalid sort_by"))
    Error(inventory_planning_handler.InvalidGroupBy) ->
      json_response(400, json_codec.encode_error("invalid group_by"))
    Error(_) ->
      json_response(
        400,
        json_codec.encode_error("invalid inventory projection request"),
      )
  }
}

// ---- Settings ---------------------------------------------------------------

fn handle_get_settings(deps: Dependencies) -> Response(mist.ResponseData) {
  let settings = settings_handler.get_settings(deps.settings_repository)
  json_response(200, json_codec.encode_settings(settings))
}

fn handle_update_settings(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- with_json_body(req)
  case json_codec.decode_update_settings_body(body) {
    Error(msg) -> json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      settings_handler.update_settings(
        deps.settings_repository,
        settings_handler.UpdateSettingsRequest(
          default_sort: b.default_sort,
          default_grouping: b.default_grouping,
        ),
      )
      json_response(200, json_codec.encode_ok("settings saved"))
    }
  }
}

// ---- Helpers ----------------------------------------------------------------

fn path_without_query(path: String) -> String {
  case string.split(path, "?") {
    [p, ..] -> p
    _ -> path
  }
}

fn with_json_body(
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

fn query_param(
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

fn json_response(status: Int, body: String) -> Response(mist.ResponseData) {
  response.new(status)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(
    body
    |> bytes_tree.from_string
    |> mist.Bytes,
  )
}

@external(erlang, "os", "getenv")
fn erl_getenv(name: charlist.Charlist) -> String

fn get_env(name: String) -> Result(String, Nil) {
  let result = erl_getenv(charlist.from_string(name))
  case result {
    "" -> Error(Nil)
    value -> Ok(value)
  }
}

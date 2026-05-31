import composition.{type Dependencies}
import driver/http/json_codec
import driver/skir/card_catalog_handler
import driver/skir/collection_import_handler
import driver/skir/inventory_planning_handler
import driver/skir/settings_handler
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

  let handler = fn(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
    handle_request(req, deps)
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
) -> Response(mist.ResponseData) {
  let path = case string.split(req.path, "?") {
    [p, ..] -> p
    _ -> req.path
  }

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
  card_catalog_handler.refresh_catalog(deps.card_catalog_repository)
  json_response(200, json_codec.encode_ok("catalog refreshed"))
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
      inventory_planning_handler.upsert_inventory_rule(
        deps.inventory_planning_repository,
        inventory_planning_handler.UpsertInventoryRuleRequest(
          id: b.id,
          location_name: b.location_name,
          expression: b.expression,
        ),
      )
      json_response(200, json_codec.encode_ok("rule saved"))
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
  let group_by = query_param(req, "group_by") |> result.unwrap("location")
  let rows =
    inventory_planning_handler.inventory_projection(
      deps.inventory_planning_repository,
      inventory_planning_handler.InventoryProjectionRequest(
        sort_by: sort_by,
        group_by: group_by,
      ),
    )
  json_response(200, json_codec.encode_inventory_projection(rows))
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

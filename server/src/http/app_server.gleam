import catalog/skir/handler as card_catalog_handler
import collection/skir/handler as collection_handler
import common/os_runtime
import composition.{type Dependencies}
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import http/json_codec
import inventory_planning/skir/handler as inventory_planning_handler
import mist
import skir/router as skir_router
import skir/setup as skir_setup

type CatalogRefreshLaunch {
  RefreshStarted
  RefreshAlreadyRunning
}

pub fn start(deps: Dependencies) -> Nil {
  let port = read_port()
  let rpc_service = skir_setup.make_service()
  let server_name = process.new_name("skir_rpc_server")
  let refresh_worker_name = process.new_name("catalog_refresh_worker")

  let _server_pid =
    process.spawn(fn() {
      skir_setup.start_server_loop(
        server_name,
        skir_setup.ServerState(service: rpc_service, context: deps),
      )
    })

  let handler = fn(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
    handle_request(req, deps, server_name, refresh_worker_name)
  }

  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start

  let _ = launch_catalog_refresh(deps, refresh_worker_name, "startup")

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
  refresh_worker_name: process.Name(Nil),
) -> Response(mist.ResponseData) {
  let path = path_without_query(req.path)

  case req.method, path {
    Get, "/api/catalog/cards" -> handle_list_catalog_cards(deps)
    Post, "/api/catalog/refresh" ->
      handle_refresh_catalog(deps, refresh_worker_name)
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

fn handle_list_catalog_cards(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let cards =
    card_catalog_handler.list_catalog_cards(deps.list_catalog_cards_port)
  json_response(200, json_codec.encode_catalog_cards(cards))
}

fn handle_refresh_catalog(
  deps: Dependencies,
  refresh_worker_name: process.Name(Nil),
) -> Response(mist.ResponseData) {
  case launch_catalog_refresh(deps, refresh_worker_name, "manual") {
    RefreshStarted ->
      json_response(202, json_codec.encode_ok("catalog refresh started"))
    RefreshAlreadyRunning ->
      json_response(
        202,
        json_codec.encode_ok("catalog refresh already running"),
      )
  }
}

fn launch_catalog_refresh(
  deps: Dependencies,
  refresh_worker_name: process.Name(Nil),
  trigger: String,
) -> CatalogRefreshLaunch {
  let refresh_subject = process.named_subject(refresh_worker_name)

  case process.subject_owner(refresh_subject) {
    Ok(_) -> {
      log_async(
        "catalog-refresh",
        "already running, skipped trigger: " <> trigger,
      )
      RefreshAlreadyRunning
    }
    Error(_) -> {
      let _ =
        process.spawn_unlinked(fn() {
          case process.register(process.self(), refresh_worker_name) {
            Ok(_) -> {
              log_async("catalog-refresh", "started: " <> trigger)
              case
                card_catalog_handler.refresh_catalog(deps.refresh_catalog_port)
              {
                card_catalog_handler.Success ->
                  log_async(
                    "catalog-refresh",
                    "finished successfully: " <> trigger,
                  )
                card_catalog_handler.Failed ->
                  log_async(
                    "catalog-refresh",
                    "finished with failure: " <> trigger,
                  )
              }
              Nil
            }
            Error(_) -> {
              log_async(
                "catalog-refresh",
                "registration race, skipping: " <> trigger,
              )
              Nil
            }
          }
        })

      RefreshStarted
    }
  }
}

fn log_async(process_name: String, message: String) -> Nil {
  io.println("[async][" <> process_name <> "] " <> message)
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
      collection_handler.import_collection(
        deps.import_collection_port,
        b.import_run_id,
        b.source_name,
        b.source_checksum,
        b.row_count,
        [],
      )
      json_response(202, json_codec.encode_ok("accepted"))
    }
  }
}

fn handle_latest_import_status(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    collection_handler.get_latest_import_status(deps.latest_import_status_port)
  {
    collection_handler.ImportStatusFound(run) ->
      json_response(200, json_codec.encode_import_status_found(run))
    collection_handler.ImportStatusNotFound ->
      json_response(200, json_codec.encode_import_status_not_found())
  }
}

// ---- Inventory planning -----------------------------------------------------

fn handle_list_inventory_rules(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let rules =
    inventory_planning_handler.list_inventory_rules(
      deps.list_inventory_rules_port,
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
          deps.upsert_inventory_rule_port,
          b.id,
          b.location_name,
          b.expression,
        )
      {
        Ok(_) -> json_response(200, json_codec.encode_ok("rule saved"))
        Error(_) ->
          json_response(
            400,
            json_codec.encode_error("invalid inventory rule expression"),
          )
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
        deps.delete_inventory_rule_port,
        b.id,
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
      deps.inventory_projection_port,
      sort_by,
      group_by,
    )

  case rows_result {
    Ok(rows) -> json_response(200, json_codec.encode_inventory_projection(rows))
    Error(inventory_planning_handler.InvalidSortBy) ->
      json_response(400, json_codec.encode_error("invalid sort_by"))
    Error(inventory_planning_handler.InvalidGroupBy) ->
      json_response(400, json_codec.encode_error("invalid group_by"))
  }
}

// ---- Planning preferences ---------------------------------------------------

fn handle_get_settings(deps: Dependencies) -> Response(mist.ResponseData) {
  let prefs =
    inventory_planning_handler.get_planning_preferences(
      deps.get_planning_preferences_port,
    )
  json_response(200, json_codec.encode_settings(prefs))
}

fn handle_update_settings(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- with_json_body(req)
  case json_codec.decode_update_settings_body(body) {
    Error(msg) -> json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      inventory_planning_handler.update_planning_preferences(
        deps.update_planning_preferences_port,
        b.default_sort,
        b.default_grouping,
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

fn get_env(name: String) -> Result(String, Nil) {
  os_runtime.getenv(name)
}

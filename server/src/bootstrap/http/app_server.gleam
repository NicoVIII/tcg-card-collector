import bootstrap/composition.{type Dependencies}
import bootstrap/skir/router as skir_router
import bootstrap/skir/setup as skir_setup
import card_catalog/driver/http/handler as catalog_http
import card_catalog/driver/refresh_launcher
import collection/driver/http/handler as collection_http
import gleam/erlang/process
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/result
import gleam/string
import insights/driver/http/handler as insights_http
import inventory_planning/driver/http/handler as inventory_http
import mist
import shared/driver/http/helpers
import shared/driver/http/json_codec
import shared/driver/http/static_files
import shared/infrastructure/os_runtime

pub fn start(deps: Dependencies) -> Nil {
  let port = read_port()
  let static_root = read_static_root()
  let server_name = process.new_name("skir_rpc_server")

  // The service term is a sharing-heavy DAG (flat size in the tens of GB);
  // it must be built on the server-loop process itself, because capturing it
  // in the spawn closure would flatten that sharing during the spawn copy.
  let _server_pid =
    process.spawn(fn() {
      skir_setup.start_server_loop(
        server_name,
        skir_setup.ServerState(
          service: skir_setup.make_service(),
          context: deps,
        ),
      )
    })

  let handler = fn(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
    handle_request(req, deps, server_name, static_root)
  }

  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start

  let _ =
    refresh_launcher.launch(
      deps.catalog,
      deps.catalog.refresh_worker_name,
      "startup",
    )

  process.sleep_forever()
}

fn read_port() -> Int {
  get_env("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}

fn read_static_root() -> String {
  os_runtime.getenv_or("STATIC_DIR", "./static")
}

fn handle_request(
  req: Request(mist.Connection),
  deps: Dependencies,
  server_name: skir_setup.ServerName,
  static_root: String,
) -> Response(mist.ResponseData) {
  let path = path_without_query(req.path)

  case req.method, path {
    Get, "/api/catalog/cards" ->
      catalog_http.handle_list_catalog_cards(deps.catalog)
    Post, "/api/catalog/cards/lookup" ->
      catalog_http.handle_get_catalog_cards(req, deps.catalog)
    Post, "/api/catalog/refresh" ->
      catalog_http.handle_refresh_catalog(deps.catalog)
    Get, "/api/catalog/refresh/latest" ->
      catalog_http.handle_refresh_status(deps.catalog)
    Post, "/api/import" ->
      collection_http.handle_import_collection(req, deps.collection)
    Post, "/api/collection/cards" ->
      collection_http.handle_add_cards(req, deps.collection)
    Get, "/api/inventory/rules" ->
      inventory_http.handle_list_inventory_rules(deps.inventory_planning)
    Put, "/api/inventory/rules" ->
      inventory_http.handle_upsert_inventory_rule(req, deps.inventory_planning)
    Delete, "/api/inventory/rules" ->
      inventory_http.handle_delete_inventory_rule(req, deps.inventory_planning)
    Get, "/api/inventory/projection" ->
      inventory_http.handle_inventory_projection(deps.inventory_planning)
    Get, "/api/inventory/bulk-spec" ->
      inventory_http.handle_get_bulk_spec(deps.inventory_planning)
    Put, "/api/inventory/bulk-spec" ->
      inventory_http.handle_update_bulk_spec(req, deps.inventory_planning)
    Get, "/api/inventory/placement-guidance" ->
      inventory_http.handle_placement_guidance(deps.inventory_planning)
    Post, "/api/inventory/placements" ->
      inventory_http.handle_mark_cards_placed(req, deps.inventory_planning)
    Delete, "/api/inventory/placements" ->
      inventory_http.handle_unmark_cards_placed(req, deps.inventory_planning)
    Get, "/api/settings" ->
      inventory_http.handle_get_settings(deps.inventory_planning)
    Put, "/api/settings" ->
      inventory_http.handle_update_settings(req, deps.inventory_planning)
    Get, "/api/insights/completion" ->
      insights_http.handle_get_set_completion(deps.insights)
    Put, "/api/insights/targets" ->
      insights_http.handle_mark_target_set(req, deps.insights)
    Delete, "/api/insights/targets" ->
      insights_http.handle_unmark_target_set(req, deps.insights)
    Get, "/api/skir" | Post, "/api/skir" ->
      skir_router.handle_request(req, server_name)
    Get, path -> handle_get_fallback(path, static_root)
    _, _ -> helpers.json_response(404, json_codec.encode_error("not found"))
  }
}

fn handle_get_fallback(
  path: String,
  static_root: String,
) -> Response(mist.ResponseData) {
  case string.starts_with(path, "/api") {
    True -> helpers.json_response(404, json_codec.encode_error("not found"))
    False -> static_files.serve(static_root, path)
  }
}

// ---- Helpers ----------------------------------------------------------------

fn path_without_query(path: String) -> String {
  case string.split(path, "?") {
    [p, ..] -> p
    _ -> path
  }
}

fn get_env(name: String) -> Result(String, Nil) {
  os_runtime.getenv(name)
}

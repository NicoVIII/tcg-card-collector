import catalog/application/handler as catalog_handler
import catalog/driver/http/json_codec as catalog_codec
import composition.{type Dependencies}
import gleam/erlang/process
import gleam/http/response.{type Response}
import gleam/io
import http/helpers
import http/json_codec
import mist

pub type CatalogRefreshLaunch {
  RefreshStarted
  RefreshAlreadyRunning
}

pub fn handle_list_catalog_cards(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let cards = catalog_handler.list_catalog_cards(deps.list_catalog_cards_port)
  helpers.json_response(200, catalog_codec.encode_catalog_cards(cards))
}

pub fn handle_refresh_catalog(
  deps: Dependencies,
  refresh_worker_name: process.Name(Nil),
) -> Response(mist.ResponseData) {
  case launch_catalog_refresh(deps, refresh_worker_name, "manual") {
    RefreshStarted ->
      helpers.json_response(
        202,
        json_codec.encode_ok("catalog refresh started"),
      )
    RefreshAlreadyRunning ->
      helpers.json_response(
        202,
        json_codec.encode_ok("catalog refresh already running"),
      )
  }
}

pub fn launch_catalog_refresh(
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
              case catalog_handler.refresh_catalog(deps.refresh_catalog_port) {
                catalog_handler.Success ->
                  log_async(
                    "catalog-refresh",
                    "finished successfully: " <> trigger,
                  )
                catalog_handler.Failed ->
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

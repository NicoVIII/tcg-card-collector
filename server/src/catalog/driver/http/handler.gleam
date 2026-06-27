import catalog/application/commands/refresh/handler.{RefreshCatalogCommand} as catalog_refresh_handler
import catalog/application/queries/list_cards/handler.{ListCatalogCardsQuery} as catalog_list_cards_handler
import catalog/driver/dependencies.{type Dependencies}
import catalog/driver/http/json_codec as catalog_codec
import gleam/erlang/process
import gleam/http/response.{type Response}
import gleam/io
import mist
import shared/driver/http/helpers

pub fn handle_list_catalog_cards(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let cards =
    catalog_list_cards_handler.execute(
      ListCatalogCardsQuery,
      deps.list_catalog_cards_port,
    )
  helpers.json_response(200, catalog_codec.encode_catalog_cards(cards))
}

pub fn handle_refresh_catalog(
  deps: Dependencies,
  refresh_worker_name: process.Name(Nil),
) -> Response(mist.ResponseData) {
  launch_catalog_refresh(deps, refresh_worker_name, "manual")
  |> catalog_codec.encode_refresh_launch
  |> helpers.json_response(202, _)
}

pub fn launch_catalog_refresh(
  deps: Dependencies,
  refresh_worker_name: process.Name(Nil),
  trigger: String,
) -> catalog_codec.CatalogRefreshLaunch {
  let refresh_subject = process.named_subject(refresh_worker_name)

  case process.subject_owner(refresh_subject) {
    Ok(_) -> {
      log_async(
        "catalog-refresh",
        "already running, skipped trigger: " <> trigger,
      )
      catalog_codec.RefreshAlreadyRunning
    }
    Error(_) -> {
      let _ =
        process.spawn_unlinked(fn() {
          case process.register(process.self(), refresh_worker_name) {
            Ok(_) -> {
              log_async("catalog-refresh", "started: " <> trigger)
              case
                catalog_refresh_handler.execute(
                  RefreshCatalogCommand,
                  deps.refresh_catalog_ports,
                )
              {
                Ok(Nil) ->
                  log_async(
                    "catalog-refresh",
                    "finished successfully: " <> trigger,
                  )
                Error(_) ->
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

      catalog_codec.RefreshStarted
    }
  }
}

fn log_async(process_name: String, message: String) -> Nil {
  io.println("[async][" <> process_name <> "] " <> message)
}

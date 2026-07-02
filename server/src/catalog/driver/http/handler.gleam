import catalog/application/queries/list_cards/handler.{ListCatalogCardsQuery} as catalog_list_cards_handler
import catalog/application/queries/refresh_status/handler.{
  GetCatalogRefreshStatusQuery,
} as refresh_status_handler
import catalog/driver/dependencies.{type Dependencies}
import catalog/driver/http/json_codec as catalog_codec
import catalog/driver/refresh_launcher
import gleam/http/response.{type Response}
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
) -> Response(mist.ResponseData) {
  refresh_launcher.launch(deps, deps.refresh_worker_name, "manual")
  |> catalog_codec.encode_refresh_launch
  |> helpers.json_response(202, _)
}

pub fn handle_refresh_status(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let status =
    refresh_status_handler.execute(
      GetCatalogRefreshStatusQuery,
      deps.get_refresh_status_port,
    )
  helpers.json_response(200, catalog_codec.encode_refresh_status(status))
}

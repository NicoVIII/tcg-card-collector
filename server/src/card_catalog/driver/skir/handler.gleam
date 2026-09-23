import card_catalog/application/queries/get_cards/handler as get_catalog_cards_handler
import card_catalog/application/queries/list_cards/handler.{
  ListCatalogCardsQuery,
} as catalog_list_cards_handler
import card_catalog/application/queries/refresh_status/handler.{
  GetCatalogRefreshStatusQuery,
} as refresh_status_handler
import card_catalog/driver/dependencies.{type Dependencies}
import card_catalog/driver/refresh_launcher
import card_catalog/driver/skir/codec as catalog_skir_codec
import gleam/list
import shared/driver/skir/helpers
import shared/driver/skir/skirout/card_catalog/commands as card_catalog_commands
import shared/driver/skir/skirout/card_catalog/queries as card_catalog_queries
import skir_client/service

fn handle_refresh_catalog(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  card_catalog_commands.RefreshCatalogRequest,
  card_catalog_commands.RefreshCatalogResponse,
  context,
) {
  fn(_: card_catalog_commands.RefreshCatalogRequest, _, ctx) {
    let deps = get_dependencies(ctx)
    refresh_launcher.launch(deps, deps.refresh_worker_name, "skir")
    |> catalog_skir_codec.map_refresh_launch_result
    |> Ok
    |> helpers.respond
  }
}

fn handle_list_catalog_cards(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  card_catalog_queries.ListCatalogCardsRequest,
  card_catalog_queries.CatalogCardKeyList,
  context,
) {
  fn(req: card_catalog_queries.ListCatalogCardsRequest, _, ctx) {
    catalog_list_cards_handler.execute(
      ListCatalogCardsQuery(filter: catalog_skir_codec.to_catalog_card_filter(
        req,
      )),
      get_dependencies(ctx).list_catalog_cards_port,
    )
    |> helpers.map_query(catalog_skir_codec.map_catalog_card_key_page(
      _,
      req.offset,
      req.limit,
    ))
    |> helpers.respond
  }
}

fn handle_get_catalog_cards(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  card_catalog_queries.GetCatalogCardsRequest,
  card_catalog_queries.CatalogCardList,
  context,
) {
  fn(req: card_catalog_queries.GetCatalogCardsRequest, _, ctx) {
    get_catalog_cards_handler.execute(
      get_catalog_cards_handler.GetCatalogCardsQuery(keys: list.map(
        req.keys,
        catalog_skir_codec.to_key_pair,
      )),
      get_dependencies(ctx).get_catalog_cards_port,
    )
    |> helpers.map_query(catalog_skir_codec.map_catalog_card_list)
    |> helpers.respond
  }
}

fn handle_get_refresh_status(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  card_catalog_queries.GetCatalogRefreshStatusRequest,
  card_catalog_queries.CatalogRefreshStatus,
  context,
) {
  fn(_: card_catalog_queries.GetCatalogRefreshStatusRequest, _, ctx) {
    refresh_status_handler.execute(
      GetCatalogRefreshStatusQuery,
      get_dependencies(ctx).get_refresh_status_port,
    )
    |> helpers.map_query(catalog_skir_codec.map_refresh_status_result)
    |> helpers.respond
  }
}

pub fn register(
  svc: service.Service(Nil, context, Nil),
  get_dependencies: fn(context) -> Dependencies,
) -> service.Service(Nil, context, Nil) {
  svc
  |> service.add_method(
    card_catalog_commands.refresh_catalog_method(),
    handle_refresh_catalog(get_dependencies),
  )
  |> service.add_method(
    card_catalog_queries.list_catalog_cards_method(),
    handle_list_catalog_cards(get_dependencies),
  )
  |> service.add_method(
    card_catalog_queries.get_catalog_cards_method(),
    handle_get_catalog_cards(get_dependencies),
  )
  |> service.add_method(
    card_catalog_queries.get_catalog_refresh_status_method(),
    handle_get_refresh_status(get_dependencies),
  )
}

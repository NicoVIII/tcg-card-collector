import card_catalog/application/queries/get_cards/handler as get_catalog_cards_handler
import card_catalog/application/queries/get_cards/ports as get_cards_ports
import card_catalog/application/queries/list_cards/handler.{
  ListCatalogCardsQuery,
} as catalog_list_cards_handler
import card_catalog/application/queries/list_cards/ports as list_cards_ports
import card_catalog/application/queries/refresh_status/handler.{
  GetCatalogRefreshStatusQuery,
} as refresh_status_handler
import card_catalog/driver/dependencies.{type Dependencies}
import card_catalog/driver/refresh_launcher
import card_catalog/driver/skir/codec as catalog_skir_codec
import gleam/list
import shared/driver/skir/skirout/card_catalog/commands as card_catalog_commands
import shared/driver/skir/skirout/card_catalog/queries as card_catalog_queries
import skir_client/service

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

fn handle_refresh_catalog(get_dependencies: fn(context) -> Dependencies) {
  fn(
    _: card_catalog_commands.RefreshCatalogRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(card_catalog_commands.RefreshCatalogResponse, service.ServiceError),
    Nil,
    Nil,
  ) {
    let deps = get_dependencies(ctx)
    let outcome =
      refresh_launcher.launch(deps, deps.refresh_worker_name, "skir")
    #(Ok(catalog_skir_codec.map_refresh_launch_result(outcome)), req_meta, Nil)
  }
}

fn handle_list_catalog_cards(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: card_catalog_queries.ListCatalogCardsRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(card_catalog_queries.CatalogCardKeyList, service.ServiceError),
    Nil,
    Nil,
  ) {
    case
      catalog_list_cards_handler.execute(
        ListCatalogCardsQuery,
        get_dependencies(ctx).list_catalog_cards_port,
      )
    {
      Ok(all_keys) -> {
        let total = list.length(all_keys)
        let paged_keys = paginate_keys(all_keys, req.offset, req.limit)
        let response =
          card_catalog_queries.catalog_card_key_list_new(
            list.map(paged_keys, map_catalog_card_key),
            req.limit,
            req.offset,
            total,
          )
        #(Ok(response), req_meta, Nil)
      }
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
    }
  }
}

fn map_catalog_card_key(
  key: list_cards_ports.CatalogCardKeyReadModel,
) -> card_catalog_queries.CatalogCardKey {
  // arg order: collector_number, set_code (alphabetical per generated constructor)
  card_catalog_queries.catalog_card_key_new(key.collector_number, key.set_code)
}

fn handle_get_catalog_cards(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: card_catalog_queries.GetCatalogCardsRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(card_catalog_queries.CatalogCardList, service.ServiceError),
    Nil,
    Nil,
  ) {
    let keys = list.map(req.keys, fn(k) { #(k.set_code, k.collector_number) })
    case
      get_catalog_cards_handler.execute(
        get_catalog_cards_handler.GetCatalogCardsQuery(keys:),
        get_dependencies(ctx).get_catalog_cards_port,
      )
    {
      Ok(cards) -> {
        let response =
          card_catalog_queries.catalog_card_list_new(list.map(
            cards,
            map_card_read_model,
          ))
        #(Ok(response), req_meta, Nil)
      }
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
    }
  }
}

fn map_card_read_model(
  card: get_cards_ports.CardReadModel,
) -> card_catalog_queries.CatalogCard {
  // arg order is alphabetical per generated constructor:
  // collector_number, color_identity, image_uri, name, oracle_id, rarity,
  // released_at, set_code, type_line
  card_catalog_queries.catalog_card_new(
    card.collector_number,
    card.color_identity,
    card.image_uri,
    card.name,
    card.oracle_id,
    card.rarity,
    card.released_at,
    card.set_code,
    card.type_line,
  )
}

fn handle_get_refresh_status(get_dependencies: fn(context) -> Dependencies) {
  fn(
    _: card_catalog_queries.GetCatalogRefreshStatusRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(card_catalog_queries.CatalogRefreshStatus, service.ServiceError),
    Nil,
    Nil,
  ) {
    case
      refresh_status_handler.execute(
        GetCatalogRefreshStatusQuery,
        get_dependencies(ctx).get_refresh_status_port,
      )
    {
      Ok(status) -> #(
        Ok(catalog_skir_codec.map_refresh_status_result(status)),
        req_meta,
        Nil,
      )
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
    }
  }
}

fn paginate_keys(
  keys: List(list_cards_ports.CatalogCardKeyReadModel),
  offset: Int,
  limit: Int,
) -> List(list_cards_ports.CatalogCardKeyReadModel) {
  let normalized_offset = clamp_non_negative(offset)
  let normalized_limit = clamp_non_negative(limit)

  keys
  |> list.drop(normalized_offset)
  |> fn(remaining) {
    case normalized_limit {
      0 -> remaining
      _ -> list.take(remaining, normalized_limit)
    }
  }
}

fn clamp_non_negative(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

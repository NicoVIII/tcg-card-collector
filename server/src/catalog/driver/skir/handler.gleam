import catalog/application/commands/refresh/handler.{RefreshCatalogCommand} as catalog_refresh_handler
import catalog/application/queries/get_cards/handler as get_catalog_cards_handler
import catalog/application/queries/get_cards/ports as get_cards_ports
import catalog/application/queries/list_cards/handler.{ListCatalogCardsQuery} as catalog_list_cards_handler
import catalog/application/queries/list_cards/ports as list_cards_ports
import catalog/driver/dependencies.{type Dependencies}
import catalog/driver/skir/codec as catalog_skir_codec
import gleam/io
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
    log_rpc("started")
    let result =
      catalog_refresh_handler.execute(
        RefreshCatalogCommand,
        get_dependencies(ctx).refresh_catalog_ports,
      )
    case result {
      Ok(_) -> log_rpc("finished successfully")
      Error(_) -> log_rpc("finished with failure")
    }
    #(catalog_skir_codec.map_refresh_catalog_result(result), req_meta, Nil)
  }
}

fn log_rpc(message: String) -> Nil {
  io.println("[rpc][catalog-refresh] " <> message)
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
    let all_keys =
      catalog_list_cards_handler.execute(
        ListCatalogCardsQuery,
        get_dependencies(ctx).list_catalog_cards_port,
      )
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
    let cards =
      get_catalog_cards_handler.execute(
        get_catalog_cards_handler.GetCatalogCardsQuery(keys:),
        get_dependencies(ctx).get_catalog_cards_port,
      )
    let response =
      card_catalog_queries.catalog_card_list_new(list.map(
        cards,
        map_card_read_model,
      ))
    #(Ok(response), req_meta, Nil)
  }
}

fn map_card_read_model(
  card: get_cards_ports.CardReadModel,
) -> card_catalog_queries.CatalogCard {
  // arg order: collector_number, image_uri, name, set_code (alphabetical per generated constructor)
  card_catalog_queries.catalog_card_new(
    card.collector_number,
    card.image_uri,
    card.name,
    card.set_code,
  )
}

fn paginate_keys(
  keys: List(list_cards_ports.CatalogCardKeyReadModel),
  offset: Int,
  limit: Int,
) -> List(list_cards_ports.CatalogCardKeyReadModel) {
  let normalized_offset = clamp_non_negative(offset)
  let normalized_limit = clamp_non_negative(limit)

  keys
  |> drop_items(normalized_offset)
  |> fn(remaining) {
    case normalized_limit {
      0 -> remaining
      _ -> take_items(remaining, normalized_limit)
    }
  }
}

fn clamp_non_negative(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

fn drop_items(items: List(a), count: Int) -> List(a) {
  case count <= 0, items {
    True, _ -> items
    False, [] -> []
    False, [_first, ..rest] -> drop_items(rest, count - 1)
  }
}

fn take_items(items: List(a), count: Int) -> List(a) {
  case count <= 0, items {
    True, _ -> []
    False, [] -> []
    False, [first, ..rest] -> [first, ..take_items(rest, count - 1)]
  }
}

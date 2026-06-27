import catalog/application/commands/refresh/handler.{RefreshCatalogCommand} as catalog_refresh_handler
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
    Result(card_catalog_queries.CatalogCardList, service.ServiceError),
    Nil,
    Nil,
  ) {
    let all_cards =
      catalog_list_cards_handler.execute(
        ListCatalogCardsQuery,
        get_dependencies(ctx).list_catalog_cards_port,
      )
    let total = list.length(all_cards)
    let paged_cards = paginate_cards(all_cards, req.offset, req.limit)
    let response =
      card_catalog_queries.catalog_card_list_new(
        list.map(paged_cards, map_catalog_card),
        req.limit,
        req.offset,
        total,
      )

    #(Ok(response), req_meta, Nil)
  }
}

fn map_catalog_card(
  card: list_cards_ports.CatalogCardReadModel,
) -> card_catalog_queries.CatalogCard {
  card_catalog_queries.catalog_card_new(card.id, card.name, card.set_code)
}

fn paginate_cards(
  cards: List(list_cards_ports.CatalogCardReadModel),
  offset: Int,
  limit: Int,
) -> List(list_cards_ports.CatalogCardReadModel) {
  let normalized_offset = clamp_non_negative(offset)
  let normalized_limit = clamp_non_negative(limit)

  cards
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

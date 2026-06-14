import catalog/application/handler as catalog_handler
import catalog/application/queries/list_cards/ports as list_cards_ports
import composition.{type Dependencies}
import gleam/io
import gleam/list
import skir/skirout/card_catalog/commands as card_catalog_commands
import skir/skirout/card_catalog/queries as card_catalog_queries
import skir_client/service

pub fn register(
  svc: service.Service(Nil, Dependencies, Nil),
) -> service.Service(Nil, Dependencies, Nil) {
  svc
  |> service.add_method(
    card_catalog_commands.refresh_catalog_method(),
    handle_refresh_catalog,
  )
  |> service.add_method(
    card_catalog_queries.list_catalog_cards_method(),
    handle_list_catalog_cards,
  )
}

fn handle_refresh_catalog(
  _: card_catalog_commands.RefreshCatalogRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(card_catalog_commands.RefreshCatalogResponse, service.ServiceError),
  Nil,
  Nil,
) {
  log_rpc("started")
  case catalog_handler.refresh_catalog(deps.refresh_catalog_ports) {
    catalog_handler.Success -> {
      log_rpc("finished successfully")
      #(Ok(card_catalog_commands.RefreshCatalogResponseSuccess), req_meta, Nil)
    }
    catalog_handler.Failed -> {
      log_rpc("finished with failure")
      #(
        Error(service.ServiceError(
          service.E503xServiceUnavailable,
          "catalog refresh failed",
        )),
        req_meta,
        Nil,
      )
    }
  }
}

fn log_rpc(message: String) -> Nil {
  io.println("[rpc][catalog-refresh] " <> message)
}

fn handle_list_catalog_cards(
  req: card_catalog_queries.ListCatalogCardsRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(card_catalog_queries.CatalogCardList, service.ServiceError),
  Nil,
  Nil,
) {
  let all_cards =
    catalog_handler.list_catalog_cards(deps.list_catalog_cards_port)
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

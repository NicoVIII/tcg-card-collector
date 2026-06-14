import application/queries/inventory_planning/list_rules/ports as list_rules_ports
import application/queries/inventory_planning/projection/ports as projection_ports
import catalog/application/queries/list_cards/ports as list_cards_ports
import catalog/skir/handler as card_catalog_handler
import collection/skir/handler as collection_handler
import composition.{type Dependencies}
import driver/skir/inventory_planning_handler
import driver/skirout/card_catalog/commands as card_catalog_commands
import driver/skirout/card_catalog/queries as card_catalog_queries
import driver/skirout/collection/commands as collection_commands
import driver/skirout/collection/queries as collection_queries
import driver/skirout/inventory_planning/commands as inventory_planning_commands
import driver/skirout/inventory_planning/queries as inventory_planning_queries
import gleam/erlang/process
import gleam/io
import gleam/list
import skir_client/service

pub type RpcService =
  service.Service(Nil, Dependencies, Nil)

pub type ServerMessage {
  HandleRpc(body: String, reply: process.Subject(service.RawResponse))
}

pub type ServerName =
  process.Name(ServerMessage)

pub type ServerState {
  ServerState(service: RpcService, context: Dependencies)
}

pub fn make_service() -> RpcService {
  service.new(empty_message: Nil)
  |> service.add_method(
    card_catalog_commands.refresh_catalog_method(),
    handle_refresh_catalog,
  )
  |> service.add_method(
    card_catalog_queries.list_catalog_cards_method(),
    handle_list_catalog_cards,
  )
  |> service.add_method(
    collection_commands.import_collection_method(),
    handle_import_collection,
  )
  |> service.add_method(
    collection_queries.get_latest_import_status_method(),
    handle_get_latest_import_status,
  )
  |> service.add_method(
    inventory_planning_commands.upsert_inventory_rule_method(),
    handle_upsert_inventory_rule,
  )
  |> service.add_method(
    inventory_planning_commands.delete_inventory_rule_method(),
    handle_delete_inventory_rule,
  )
  |> service.add_method(
    inventory_planning_queries.list_inventory_rules_method(),
    handle_list_inventory_rules,
  )
  |> service.add_method(
    inventory_planning_queries.get_inventory_projection_method(),
    handle_get_inventory_projection,
  )
  |> service.add_method(
    inventory_planning_queries.get_planning_preferences_method(),
    handle_get_planning_preferences,
  )
  |> service.add_method(
    inventory_planning_commands.update_planning_preferences_method(),
    handle_update_planning_preferences,
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
  case card_catalog_handler.refresh_catalog(deps.refresh_catalog_port) {
    card_catalog_handler.Success -> {
      log_rpc("finished successfully")
      #(Ok(card_catalog_commands.RefreshCatalogResponseSuccess), req_meta, Nil)
    }
    card_catalog_handler.Failed -> {
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
    card_catalog_handler.list_catalog_cards(deps.list_catalog_cards_port)
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

fn handle_import_collection(
  req: collection_commands.ImportCollectionRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(collection_commands.ImportCollectionResponse, service.ServiceError),
  Nil,
  Nil,
) {
  collection_handler.import_collection(
    deps.import_collection_port,
    req.import_run_id,
    req.source_name,
    req.source_checksum,
    req.row_count,
    list.map(req.rows, map_import_collection_row),
  )
  |> fn(response) {
    case response {
      collection_handler.Accepted -> #(
        Ok(collection_commands.ImportCollectionResponseAccepted),
        req_meta,
        Nil,
      )
      collection_handler.Rejected -> #(
        Ok(collection_commands.ImportCollectionResponseRejected),
        req_meta,
        Nil,
      )
    }
  }
}

fn handle_get_latest_import_status(
  _: collection_queries.GetLatestImportStatusRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(Result(collection_queries.ImportStatus, service.ServiceError), Nil, Nil) {
  let response =
    collection_handler.get_latest_import_status(deps.latest_import_status_port)

  case response {
    collection_handler.ImportStatusFound(run) -> #(
      Ok(collection_queries.import_status_new(
        run.id,
        run.row_count,
        run.source_name,
        collection_handler.status_to_string(run.status),
      )),
      req_meta,
      Nil,
    )
    collection_handler.ImportStatusNotFound -> #(
      Error(service.ServiceError(
        service.E404xNotFound,
        "import status not found",
      )),
      req_meta,
      Nil,
    )
  }
}

fn handle_upsert_inventory_rule(
  req: inventory_planning_commands.UpsertInventoryRuleRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    inventory_planning_commands.UpsertInventoryRuleResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  case
    inventory_planning_handler.upsert_inventory_rule(
      deps.upsert_inventory_rule_port,
      req.id,
      req.location_name,
      req.expression,
    )
  {
    Ok(_) -> #(
      Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess),
      req_meta,
      Nil,
    )
    Error(_) -> #(
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule expression",
      )),
      req_meta,
      Nil,
    )
  }
}

fn handle_delete_inventory_rule(
  req: inventory_planning_commands.DeleteInventoryRuleRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    inventory_planning_commands.DeleteInventoryRuleResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  inventory_planning_handler.delete_inventory_rule(
    deps.delete_inventory_rule_port,
    req.id,
  )

  #(
    Ok(inventory_planning_commands.DeleteInventoryRuleResponseSuccess),
    req_meta,
    Nil,
  )
}

fn handle_list_inventory_rules(
  _: inventory_planning_queries.ListInventoryRulesRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(inventory_planning_queries.InventoryRuleList, service.ServiceError),
  Nil,
  Nil,
) {
  let rules =
    inventory_planning_handler.list_inventory_rules(
      deps.list_inventory_rules_port,
    )
  let response =
    inventory_planning_queries.inventory_rule_list_new(
      list.map(rules, map_inventory_rule),
      list.length(rules),
    )

  #(Ok(response), req_meta, Nil)
}

fn handle_get_inventory_projection(
  req: inventory_planning_queries.InventoryProjectionRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(inventory_planning_queries.InventoryProjection, service.ServiceError),
  Nil,
  Nil,
) {
  let rows_result =
    inventory_planning_handler.inventory_projection(
      deps.inventory_projection_port,
      req.sort_by,
      req.group_by,
    )

  case rows_result {
    Ok(rows) -> {
      let response =
        inventory_planning_queries.inventory_projection_new(
          list.map(rows, map_inventory_projection_row),
          list.length(rows),
        )

      #(Ok(response), req_meta, Nil)
    }
    Error(inventory_planning_handler.InvalidSortBy) -> #(
      Error(service.ServiceError(service.E400xBadRequest, "invalid sort_by")),
      req_meta,
      Nil,
    )
    Error(inventory_planning_handler.InvalidGroupBy) -> #(
      Error(service.ServiceError(service.E400xBadRequest, "invalid group_by")),
      req_meta,
      Nil,
    )
  }
}

fn handle_get_planning_preferences(
  _: inventory_planning_queries.GetPlanningPreferencesRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(inventory_planning_queries.PlanningPreferences, service.ServiceError),
  Nil,
  Nil,
) {
  let current =
    inventory_planning_handler.get_planning_preferences(
      deps.get_planning_preferences_port,
    )
  let response =
    inventory_planning_queries.planning_preferences_new(
      current.default_grouping,
      current.default_sort,
    )

  #(Ok(response), req_meta, Nil)
}

fn handle_update_planning_preferences(
  req: inventory_planning_commands.UpdatePlanningPreferencesRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    inventory_planning_commands.UpdatePlanningPreferencesResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  inventory_planning_handler.update_planning_preferences(
    deps.update_planning_preferences_port,
    req.default_sort,
    req.default_grouping,
  )

  #(
    Ok(inventory_planning_commands.UpdatePlanningPreferencesResponseSuccess),
    req_meta,
    Nil,
  )
}

fn map_catalog_card(
  card: list_cards_ports.CatalogCardReadModel,
) -> card_catalog_queries.CatalogCard {
  card_catalog_queries.catalog_card_new(card.id, card.name, card.set_code)
}

fn map_inventory_rule(
  rule: list_rules_ports.InventoryRuleReadModel,
) -> inventory_planning_queries.InventoryRule {
  inventory_planning_queries.inventory_rule_new(
    rule.expression,
    rule.id,
    rule.location_name,
  )
}

fn map_inventory_projection_row(
  row: projection_ports.InventoryProjectionReadModel,
) -> inventory_planning_queries.InventoryProjectionRow {
  inventory_planning_queries.inventory_projection_row_new(
    row.card_name,
    row.group_value,
    row.location_name,
    row.quantity,
    row.set_code,
  )
}

fn map_import_collection_row(
  row: collection_commands.ImportCollectionRow,
) -> collection_handler.ImportCollectionRow {
  collection_handler.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
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

fn handle_server_message(
  state: ServerState,
  message: ServerMessage,
) -> ServerState {
  let HandleRpc(body, reply) = message

  let #(raw, _) =
    service.handle_request(state.service, body, Nil, state.context)
  process.send(reply, raw)
  state
}

fn server_loop(
  subject: process.Subject(ServerMessage),
  state: ServerState,
) -> Nil {
  let message = process.receive_forever(subject)
  let new_state = handle_server_message(state, message)
  server_loop(subject, new_state)
}

pub fn start_server_loop(name: ServerName, initial_state: ServerState) -> Nil {
  let assert Ok(_) = process.register(process.self(), name)
  let subject = process.named_subject(name)
  server_loop(subject, initial_state)
}

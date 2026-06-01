import application/card_catalog/ports as card_catalog_ports
import application/inventory_planning/ports as inventory_planning_ports
import composition.{type Dependencies}
import driver/skir/card_catalog_handler
import driver/skir/collection_import_handler
import driver/skir/inventory_planning_handler
import driver/skir/settings_handler
import driver/skirout/card_catalog/commands as card_catalog_commands
import driver/skirout/card_catalog/queries as card_catalog_queries
import driver/skirout/collection_import/commands as collection_import_commands
import driver/skirout/collection_import/queries as collection_import_queries
import driver/skirout/inventory_planning/commands as inventory_planning_commands
import driver/skirout/inventory_planning/queries as inventory_planning_queries
import driver/skirout/settings/commands as settings_commands
import driver/skirout/settings/queries as settings_queries
import gleam/erlang/process
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
    collection_import_commands.import_collection_method(),
    handle_import_collection,
  )
  |> service.add_method(
    collection_import_queries.get_latest_import_status_method(),
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
    settings_queries.get_settings_method(),
    handle_get_settings,
  )
  |> service.add_method(
    settings_commands.update_settings_method(),
    handle_update_settings,
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
  case card_catalog_handler.refresh_catalog(deps.card_catalog_repository) {
    card_catalog_handler.Success -> #(
      Ok(card_catalog_commands.RefreshCatalogResponseSuccess),
      req_meta,
      Nil,
    )
    card_catalog_handler.Failed -> #(
      Error(service.ServiceError(
        service.E503xServiceUnavailable,
        "catalog refresh failed",
      )),
      req_meta,
      Nil,
    )
  }
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
    card_catalog_handler.list_catalog_cards(deps.card_catalog_repository)
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
  req: collection_import_commands.ImportCollectionRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    collection_import_commands.ImportCollectionResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  collection_import_handler.import_collection(
    deps.collection_import_repository,
    collection_import_handler.ImportCollectionRequest(
      import_run_id: req.import_run_id,
      source_name: req.source_name,
      source_checksum: req.source_checksum,
      row_count: req.row_count,
      rows: list.map(req.rows, map_import_collection_row),
    ),
  )
  |> fn(response) {
    case response {
      collection_import_handler.Accepted -> #(
        Ok(collection_import_commands.ImportCollectionResponseAccepted),
        req_meta,
        Nil,
      )
      collection_import_handler.Rejected -> #(
        Ok(collection_import_commands.ImportCollectionResponseRejected),
        req_meta,
        Nil,
      )
    }
  }
}

fn handle_get_latest_import_status(
  _: collection_import_queries.GetLatestImportStatusRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(collection_import_queries.ImportStatus, service.ServiceError),
  Nil,
  Nil,
) {
  let response =
    collection_import_handler.get_latest_import_status(
      deps.collection_import_repository,
    )

  case response {
    collection_import_handler.ImportStatusFound(run) -> #(
      Ok(collection_import_queries.import_status_new(
        run.id,
        run.row_count,
        run.source_name,
        run.status,
      )),
      req_meta,
      Nil,
    )
    collection_import_handler.ImportStatusNotFound -> #(
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
      deps.inventory_planning_repository,
      inventory_planning_handler.UpsertInventoryRuleRequest(
        id: req.id,
        location_name: req.location_name,
        expression: req.expression,
      ),
    )
  {
    Ok(_) -> #(
      Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess),
      req_meta,
      Nil,
    )
    Error(inventory_planning_handler.InvalidRuleExpression) -> #(
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule expression",
      )),
      req_meta,
      Nil,
    )
    Error(_) -> #(
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule",
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
    deps.inventory_planning_repository,
    inventory_planning_handler.DeleteInventoryRuleRequest(id: req.id),
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
      deps.inventory_planning_repository,
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
      deps.inventory_planning_repository,
      inventory_planning_handler.InventoryProjectionRequest(
        sort_by: req.sort_by,
        group_by: req.group_by,
      ),
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
    Error(_) -> #(
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory projection request",
      )),
      req_meta,
      Nil,
    )
  }
}

fn handle_get_settings(
  _: settings_queries.GetSettingsRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(Result(settings_queries.AppSettings, service.ServiceError), Nil, Nil) {
  let current = settings_handler.get_settings(deps.settings_repository)
  let response =
    settings_queries.app_settings_new(
      current.default_grouping,
      current.default_sort,
    )

  #(Ok(response), req_meta, Nil)
}

fn handle_update_settings(
  req: settings_commands.UpdateSettingsRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(settings_commands.UpdateSettingsResponse, service.ServiceError),
  Nil,
  Nil,
) {
  settings_handler.update_settings(
    deps.settings_repository,
    settings_handler.UpdateSettingsRequest(
      default_sort: req.default_sort,
      default_grouping: req.default_grouping,
    ),
  )

  #(Ok(settings_commands.UpdateSettingsResponseSuccess), req_meta, Nil)
}

fn map_catalog_card(
  card: card_catalog_ports.CatalogCardReadModel,
) -> card_catalog_queries.CatalogCard {
  card_catalog_queries.catalog_card_new(card.id, card.name, card.set_code)
}

fn map_inventory_rule(
  rule: inventory_planning_ports.InventoryRuleReadModel,
) -> inventory_planning_queries.InventoryRule {
  inventory_planning_queries.inventory_rule_new(
    rule.expression,
    rule.id,
    rule.location_name,
  )
}

fn map_inventory_projection_row(
  row: inventory_planning_ports.InventoryProjectionReadModel,
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
  row: collection_import_commands.ImportCollectionRow,
) -> collection_import_handler.ImportCollectionRow {
  collection_import_handler.ImportCollectionRow(
    card_name: row.card_name,
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

fn paginate_cards(
  cards: List(card_catalog_ports.CatalogCardReadModel),
  offset: Int,
  limit: Int,
) -> List(card_catalog_ports.CatalogCardReadModel) {
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

import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/mark_cards_placed/handler as mark_cards_placed_handler
import inventory_planning/application/commands/reorder_rules/handler as reorder_rules_handler
import inventory_planning/application/commands/unmark_cards_placed/handler as unmark_cards_placed_handler
import inventory_planning/application/commands/update_bulk_spec/handler as update_bulk_spec_handler
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/placed_ledger/handler as placed_ledger_handler
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/driver/dependencies.{type Dependencies}
import inventory_planning/driver/error_presentation
import inventory_planning/driver/http/json_codec as inventory_codec
import mist
import shared/driver/http/helpers
import shared/driver/http/json_codec

pub fn handle_list_inventory_rules(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  list_rules_handler.execute(
    list_rules_handler.ListInventoryRulesQuery,
    deps.list_inventory_rules_port,
  )
  |> helpers.query_response(inventory_codec.encode_inventory_rules)
}

pub fn handle_upsert_inventory_rule(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_upsert_rule_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) -> {
      case
        upsert_rule_handler.execute(
          upsert_rule_handler.UpsertInventoryRuleCommand(
            id: b.id,
            location_name: b.location_name,
            expression: b.expression,
            position: b.position,
            selector: b.selector,
            sort_keys: b.sort_keys,
          ),
          deps.upsert_inventory_rule_port,
        )
      {
        Ok(_) -> helpers.json_response(200, json_codec.encode_ok("rule saved"))
        Error(error) ->
          helpers.error_response(error_presentation.upsert_rule(error))
      }
    }
  }
}

pub fn handle_delete_inventory_rule(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_delete_rule_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        delete_rule_handler.execute(
          delete_rule_handler.DeleteInventoryRuleCommand(id: b.id),
          deps.delete_inventory_rule_port,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("rule deleted"))
        Error(error) ->
          helpers.error_response(error_presentation.delete_rule(error))
      }
  }
}

pub fn handle_reorder_inventory_rules(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_reorder_rules_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        reorder_rules_handler.execute(
          reorder_rules_handler.ReorderInventoryRulesCommand(
            ordered_ids: b.ordered_ids,
          ),
          deps.reorder_inventory_rules_ports,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("rules reordered"))
        Error(error) ->
          helpers.error_response(error_presentation.reorder_rules(error))
      }
  }
}

pub fn handle_inventory_projection(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  projection_handler.execute(
    projection_handler.InventoryProjectionQuery,
    deps.inventory_projection_ports,
  )
  |> helpers.query_response(inventory_codec.encode_inventory_projection)
}

pub fn handle_get_bulk_spec(deps: Dependencies) -> Response(mist.ResponseData) {
  get_bulk_spec_handler.execute(
    get_bulk_spec_handler.GetBulkSpecQuery,
    deps.get_bulk_spec_port,
  )
  |> helpers.query_response(inventory_codec.encode_bulk_spec)
}

pub fn handle_update_bulk_spec(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_update_bulk_spec_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        update_bulk_spec_handler.execute(
          update_bulk_spec_handler.UpdateBulkSpecCommand(
            location_name: b.location_name,
            sort_keys: b.sort_keys,
          ),
          deps.update_bulk_spec_port,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("bulk spec saved"))
        Error(error) ->
          helpers.error_response(error_presentation.update_bulk_spec(error))
      }
  }
}

pub fn handle_placed_ledger(deps: Dependencies) -> Response(mist.ResponseData) {
  placed_ledger_handler.execute(
    placed_ledger_handler.GetPlacedLedgerQuery,
    deps.get_placed_ledger_port,
  )
  |> helpers.query_response(inventory_codec.encode_placed_ledger)
}

pub fn handle_mark_cards_placed(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_placements_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(placements) ->
      case
        mark_cards_placed_handler.execute(
          mark_cards_placed_handler.MarkCardsPlacedCommand(placements: list.map(
            placements,
            to_mark_raw_placement,
          )),
          deps.mark_cards_placed_port,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("cards placed"))
        Error(error) ->
          helpers.error_response(error_presentation.mark_cards_placed(error))
      }
  }
}

pub fn handle_unmark_cards_placed(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_placements_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(placements) ->
      case
        unmark_cards_placed_handler.execute(
          unmark_cards_placed_handler.UnmarkCardsPlacedCommand(
            placements: list.map(placements, to_unmark_raw_placement),
          ),
          deps.unmark_cards_placed_port,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("cards unplaced"))
        Error(error) ->
          helpers.error_response(error_presentation.unmark_cards_placed(error))
      }
  }
}

fn to_mark_raw_placement(
  body: inventory_codec.PlacementBody,
) -> mark_cards_placed_handler.RawPlacement {
  mark_cards_placed_handler.RawPlacement(
    set_code: body.set_code,
    collector_number: body.collector_number,
    finish: body.finish,
    language: body.language,
    location_name: body.location_name,
    quantity: body.quantity,
  )
}

fn to_unmark_raw_placement(
  body: inventory_codec.PlacementBody,
) -> unmark_cards_placed_handler.RawPlacement {
  unmark_cards_placed_handler.RawPlacement(
    set_code: body.set_code,
    collector_number: body.collector_number,
    finish: body.finish,
    language: body.language,
    location_name: body.location_name,
    quantity: body.quantity,
  )
}

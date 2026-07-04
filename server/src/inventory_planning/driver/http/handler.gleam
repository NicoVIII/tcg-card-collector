import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/update_bulk_spec/handler as update_bulk_spec_handler
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/handler as update_preferences_handler
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/get_preferences/handler as get_preferences_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/driver/dependencies.{type Dependencies}
import inventory_planning/driver/http/json_codec as inventory_codec
import mist
import shared/driver/http/helpers
import shared/driver/http/json_codec

pub fn handle_list_inventory_rules(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let rules =
    list_rules_handler.execute(
      list_rules_handler.ListInventoryRulesQuery,
      deps.list_inventory_rules_port,
    )
  helpers.json_response(200, inventory_codec.encode_inventory_rules(rules))
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
          ),
          deps.upsert_inventory_rule_port,
        )
      {
        Ok(_) -> helpers.json_response(200, json_codec.encode_ok("rule saved"))
        Error(upsert_rule_ports.InvalidExpression) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid inventory rule expression"),
          )
        Error(upsert_rule_ports.InvalidSelector) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid inventory rule selector"),
          )
        Error(upsert_rule_ports.PersistenceFailed(_)) ->
          helpers.json_response(
            500,
            json_codec.encode_error("failed to save inventory rule"),
          )
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
        Error(_) ->
          helpers.json_response(
            500,
            json_codec.encode_error("failed to delete inventory rule"),
          )
      }
  }
}

pub fn handle_inventory_projection(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    projection_handler.execute(
      projection_handler.InventoryProjectionQuery,
      deps.inventory_projection_ports,
    )
  {
    Ok(projection) ->
      helpers.json_response(
        200,
        inventory_codec.encode_inventory_projection(projection),
      )
    Error(reason) -> helpers.json_response(500, json_codec.encode_error(reason))
  }
}

pub fn handle_get_bulk_spec(deps: Dependencies) -> Response(mist.ResponseData) {
  let spec =
    get_bulk_spec_handler.execute(
      get_bulk_spec_handler.GetBulkSpecQuery,
      deps.get_bulk_spec_port,
    )
  helpers.json_response(200, inventory_codec.encode_bulk_spec(spec))
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
        Error(update_bulk_spec_ports.InvalidSortKeys) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid bulk sort keys"),
          )
        Error(update_bulk_spec_ports.PersistenceFailed(_)) ->
          helpers.json_response(
            500,
            json_codec.encode_error("failed to save bulk spec"),
          )
      }
  }
}

pub fn handle_get_settings(deps: Dependencies) -> Response(mist.ResponseData) {
  let prefs =
    get_preferences_handler.execute(
      get_preferences_handler.GetPlanningPreferencesQuery,
      deps.get_planning_preferences_port,
    )
  helpers.json_response(200, inventory_codec.encode_settings(prefs))
}

pub fn handle_update_settings(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case inventory_codec.decode_update_settings_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        update_preferences_handler.execute(
          update_preferences_handler.UpdatePlanningPreferencesCommand(
            default_sort: b.default_sort,
            default_grouping: b.default_grouping,
          ),
          deps.update_planning_preferences_port,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("settings saved"))
        Error(update_preferences_ports.InvalidPreferences) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid settings"),
          )
        Error(update_preferences_ports.PersistenceFailed(_)) ->
          helpers.json_response(
            500,
            json_codec.encode_error("failed to save settings"),
          )
      }
  }
}

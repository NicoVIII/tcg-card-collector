import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/result
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/update_preferences/handler as update_preferences_handler
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/queries/get_preferences/handler as get_preferences_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/domain/grouping_strategy
import inventory_planning/domain/sort_strategy
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
          ),
          deps.upsert_inventory_rule_port,
        )
      {
        Ok(_) -> helpers.json_response(200, json_codec.encode_ok("rule saved"))
        Error(_) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid inventory rule expression"),
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
    Ok(b) -> {
      let _ =
        delete_rule_handler.execute(
          delete_rule_handler.DeleteInventoryRuleCommand(id: b.id),
          deps.delete_inventory_rule_port,
        )
      helpers.json_response(200, json_codec.encode_ok("rule deleted"))
    }
  }
}

pub fn handle_inventory_projection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let raw_sort_by =
    helpers.query_param(req, "sort_by") |> result.unwrap("card_name")
  let raw_group_by =
    helpers.query_param(req, "group_by") |> result.unwrap("location_name")

  case sort_strategy.parse(raw_sort_by) {
    Error(_) ->
      helpers.json_response(400, json_codec.encode_error("invalid sort_by"))
    Ok(sort_by) ->
      case grouping_strategy.parse(raw_group_by) {
        Error(_) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid group_by"),
          )
        Ok(group_by) -> {
          let rows =
            projection_handler.execute(
              projection_handler.InventoryProjectionQuery(sort_by:, group_by:),
              deps.inventory_projection_ports,
            )
          helpers.json_response(
            200,
            inventory_codec.encode_inventory_projection(rows),
          )
        }
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
    Ok(b) -> {
      let _ =
        update_preferences_handler.execute(
          update_preferences_handler.UpdatePlanningPreferencesCommand(
            default_sort: b.default_sort,
            default_grouping: b.default_grouping,
          ),
          deps.update_planning_preferences_port,
        )
      helpers.json_response(200, json_codec.encode_ok("settings saved"))
    }
  }
}

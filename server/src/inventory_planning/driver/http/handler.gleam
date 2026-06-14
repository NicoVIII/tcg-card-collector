import composition.{type Dependencies}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/result
import http/helpers
import http/json_codec
import inventory_planning/application/handler as inventory_planning_handler
import inventory_planning/driver/http/json_codec as inventory_codec
import mist

pub fn handle_list_inventory_rules(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let rules =
    inventory_planning_handler.list_inventory_rules(
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
        inventory_planning_handler.upsert_inventory_rule(
          deps.upsert_inventory_rule_port,
          b.id,
          b.location_name,
          b.expression,
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
      inventory_planning_handler.delete_inventory_rule(
        deps.delete_inventory_rule_port,
        b.id,
      )
      helpers.json_response(200, json_codec.encode_ok("rule deleted"))
    }
  }
}

pub fn handle_inventory_projection(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  let sort_by =
    helpers.query_param(req, "sort_by") |> result.unwrap("card_name")
  let group_by =
    helpers.query_param(req, "group_by") |> result.unwrap("location_name")
  let rows_result =
    inventory_planning_handler.inventory_projection(
      deps.inventory_projection_port,
      sort_by,
      group_by,
    )

  case rows_result {
    Ok(rows) ->
      helpers.json_response(
        200,
        inventory_codec.encode_inventory_projection(rows),
      )
    Error(inventory_planning_handler.InvalidSortBy) ->
      helpers.json_response(400, json_codec.encode_error("invalid sort_by"))
    Error(inventory_planning_handler.InvalidGroupBy) ->
      helpers.json_response(400, json_codec.encode_error("invalid group_by"))
  }
}

pub fn handle_get_settings(deps: Dependencies) -> Response(mist.ResponseData) {
  let prefs =
    inventory_planning_handler.get_planning_preferences(
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
      inventory_planning_handler.update_planning_preferences(
        deps.update_planning_preferences_port,
        b.default_sort,
        b.default_grouping,
      )
      helpers.json_response(200, json_codec.encode_ok("settings saved"))
    }
  }
}

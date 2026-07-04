import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import insights/application/commands/mark_target_set/handler as mark_target_set_handler
import insights/application/commands/unmark_target_set/handler as unmark_target_set_handler
import insights/application/queries/set_completion/handler as set_completion_handler
import insights/driver/dependencies.{type Dependencies}
import insights/driver/http/json_codec as insights_codec
import mist
import shared/driver/http/helpers
import shared/driver/http/json_codec

pub fn handle_mark_target_set(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case insights_codec.decode_target_set_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        mark_target_set_handler.execute(
          mark_target_set_handler.MarkTargetSetCommand(set_code: b.set_code),
          deps.mark_target_set_port,
        )
      {
        Ok(_) ->
          helpers.json_response(200, json_codec.encode_ok("target set marked"))
        Error(_) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid set code"),
          )
      }
  }
}

pub fn handle_unmark_target_set(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case insights_codec.decode_target_set_body(body) {
    Error(msg) -> helpers.json_response(400, json_codec.encode_error(msg))
    Ok(b) ->
      case
        unmark_target_set_handler.execute(
          unmark_target_set_handler.UnmarkTargetSetCommand(set_code: b.set_code),
          deps.unmark_target_set_port,
        )
      {
        Ok(_) ->
          helpers.json_response(
            200,
            json_codec.encode_ok("target set unmarked"),
          )
        Error(_) ->
          helpers.json_response(
            400,
            json_codec.encode_error("invalid set code"),
          )
      }
  }
}

pub fn handle_get_set_completion(
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    set_completion_handler.execute(
      set_completion_handler.SetCompletionQuery,
      deps.set_completion_ports,
    )
  {
    Ok(rows) ->
      helpers.json_response(200, insights_codec.encode_set_completion(rows))
    Error(reason) -> helpers.json_response(500, json_codec.encode_error(reason))
  }
}

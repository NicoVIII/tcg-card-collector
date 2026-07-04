import gleam/list
import insights/application/commands/mark_target_set/handler as mark_target_set_handler
import insights/application/commands/unmark_target_set/handler as unmark_target_set_handler
import insights/application/queries/set_completion/handler as set_completion_handler
import insights/application/queries/set_completion/ports as set_completion_ports
import insights/driver/dependencies.{type Dependencies}
import insights/driver/skir/codec as insights_skir_codec
import shared/driver/skir/skirout/insights/commands as insights_commands
import shared/driver/skir/skirout/insights/queries as insights_queries
import skir_client/service

pub fn register(
  svc: service.Service(Nil, context, Nil),
  get_dependencies: fn(context) -> Dependencies,
) -> service.Service(Nil, context, Nil) {
  svc
  |> service.add_method(
    insights_commands.mark_target_set_method(),
    handle_mark_target_set(get_dependencies),
  )
  |> service.add_method(
    insights_commands.unmark_target_set_method(),
    handle_unmark_target_set(get_dependencies),
  )
  |> service.add_method(
    insights_queries.get_set_completion_method(),
    handle_get_set_completion(get_dependencies),
  )
}

fn handle_mark_target_set(get_dependencies: fn(context) -> Dependencies) {
  fn(req: insights_commands.MarkTargetSetRequest, req_meta: Nil, ctx: context) -> #(
    Result(insights_commands.MarkTargetSetResponse, service.ServiceError),
    Nil,
    Nil,
  ) {
    let result =
      mark_target_set_handler.execute(
        mark_target_set_handler.MarkTargetSetCommand(set_code: req.set_code),
        get_dependencies(ctx).mark_target_set_port,
      )
    #(insights_skir_codec.map_mark_target_set_result(result), req_meta, Nil)
  }
}

fn handle_unmark_target_set(get_dependencies: fn(context) -> Dependencies) {
  fn(req: insights_commands.UnmarkTargetSetRequest, req_meta: Nil, ctx: context) -> #(
    Result(insights_commands.UnmarkTargetSetResponse, service.ServiceError),
    Nil,
    Nil,
  ) {
    let result =
      unmark_target_set_handler.execute(
        unmark_target_set_handler.UnmarkTargetSetCommand(set_code: req.set_code),
        get_dependencies(ctx).unmark_target_set_port,
      )
    #(insights_skir_codec.map_unmark_target_set_result(result), req_meta, Nil)
  }
}

fn handle_get_set_completion(get_dependencies: fn(context) -> Dependencies) {
  fn(_: insights_queries.GetSetCompletionRequest, req_meta: Nil, ctx: context) -> #(
    Result(insights_queries.SetCompletionList, service.ServiceError),
    Nil,
    Nil,
  ) {
    case
      set_completion_handler.execute(
        set_completion_handler.SetCompletionQuery,
        get_dependencies(ctx).set_completion_ports,
      )
    {
      Ok(rows) -> {
        let response =
          insights_queries.set_completion_list_new(list.map(rows, map_row))
        #(Ok(response), req_meta, Nil)
      }
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
    }
  }
}

fn map_row(
  row: set_completion_ports.SetCompletionReadModel,
) -> insights_queries.SetCompletion {
  insights_queries.set_completion_new(row.owned, row.set_code, row.total)
}

import portability/application/queries/export_data/handler as export_data_handler
import portability/driver/dependencies.{type Dependencies}
import portability/driver/skir/codec as portability_skir_codec
import shared/driver/skir/helpers
import shared/driver/skir/skirout/portability/queries as portability_queries
import skir_client/service

fn handle_export_data(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  portability_queries.ExportDataRequest,
  portability_queries.ExportFile,
  context,
) {
  fn(_: portability_queries.ExportDataRequest, _, ctx) {
    export_data_handler.execute(
      export_data_handler.ExportDataQuery,
      get_dependencies(ctx).export_data_ports,
    )
    |> helpers.map_query(portability_skir_codec.map_export_data)
    |> helpers.respond
  }
}

pub fn register(
  svc: service.Service(Nil, context, Nil),
  get_dependencies: fn(context) -> Dependencies,
) -> service.Service(Nil, context, Nil) {
  svc
  |> service.add_method(
    portability_queries.export_data_method(),
    handle_export_data(get_dependencies),
  )
}

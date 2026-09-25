import portability/application/commands/import_data/handler as import_data_handler
import portability/application/queries/export_data/handler as export_data_handler
import portability/application/queries/preview_import/handler as preview_import_handler
import portability/driver/dependencies.{type Dependencies}
import portability/driver/export_file
import portability/driver/skir/codec as portability_skir_codec
import shared/driver/skir/helpers
import shared/driver/skir/skirout/portability/commands as portability_commands
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

fn handle_preview_import(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  portability_queries.PreviewImportRequest,
  portability_queries.ImportPreview,
  context,
) {
  fn(req: portability_queries.PreviewImportRequest, _, ctx) {
    case export_file.parse(req.content) {
      Ok(document) ->
        Ok(
          portability_skir_codec.map_import_preview(
            preview_import_handler.execute(
              preview_import_handler.PreviewImportQuery(document:),
              get_dependencies(ctx).preview_import_ports,
            ),
          ),
        )
      Error(error) -> Error(portability_skir_codec.map_parse_error(error))
    }
    |> helpers.respond
  }
}

fn handle_import_data(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  portability_commands.ImportDataRequest,
  portability_commands.ImportedData,
  context,
) {
  fn(req: portability_commands.ImportDataRequest, _, ctx) {
    case export_file.parse(req.content) {
      Ok(document) ->
        import_data_handler.execute(
          import_data_handler.ImportDataCommand(document:),
          get_dependencies(ctx).import_data_ports,
        )
        |> portability_skir_codec.map_import_data_result
      Error(error) -> Error(portability_skir_codec.map_parse_error(error))
    }
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
  |> service.add_method(
    portability_queries.preview_import_method(),
    handle_preview_import(get_dependencies),
  )
  |> service.add_method(
    portability_commands.import_data_method(),
    handle_import_data(get_dependencies),
  )
}

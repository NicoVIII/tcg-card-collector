import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import mist
import portability/application/commands/import_data/handler as import_data_handler
import portability/application/queries/export_data/handler as export_data_handler
import portability/application/queries/preview_import/handler as preview_import_handler
import portability/driver/dependencies.{type Dependencies}
import portability/driver/error_presentation
import portability/driver/export_file
import portability/driver/http/json_codec as portability_json_codec
import shared/driver/http/helpers
import shared/driver/http/json_codec

pub fn handle_export_data(
  _req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  case
    export_data_handler.execute(
      export_data_handler.ExportDataQuery,
      deps.export_data_ports,
    )
  {
    Error(reason) -> helpers.json_response(500, json_codec.encode_error(reason))
    Ok(document) ->
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_header(
        "content-disposition",
        "attachment; filename=\"" <> export_file.filename(document) <> "\"",
      )
      |> response.set_body(
        export_file.render(document)
        |> bytes_tree.from_string
        |> mist.Bytes,
      )
  }
}

/// The request body is the export file's own content, not a JSON envelope —
/// `with_json_body` only reads the raw body as UTF-8, so it's reused here
/// unchanged (a plain `curl --data-binary @export.json` works against
/// either method).
pub fn handle_preview_import(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case export_file.parse(body) {
    Ok(document) ->
      helpers.json_response(
        200,
        portability_json_codec.encode_import_preview(
          preview_import_handler.execute(
            preview_import_handler.PreviewImportQuery(document:),
            deps.preview_import_ports,
          ),
        ),
      )
    Error(error) ->
      helpers.error_response(error_presentation.document_error(error))
  }
}

pub fn handle_import_data(
  req: Request(mist.Connection),
  deps: Dependencies,
) -> Response(mist.ResponseData) {
  use body <- helpers.with_json_body(req)
  case export_file.parse(body) {
    Error(error) ->
      helpers.error_response(error_presentation.document_error(error))
    Ok(document) ->
      case
        import_data_handler.execute(
          import_data_handler.ImportDataCommand(document:),
          deps.import_data_ports,
        )
      {
        Ok(sections) ->
          helpers.json_response(
            200,
            portability_json_codec.encode_imported_data(sections),
          )
        Error(error) ->
          helpers.error_response(error_presentation.import_data(error))
      }
  }
}

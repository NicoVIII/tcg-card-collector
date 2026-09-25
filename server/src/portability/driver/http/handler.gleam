import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import mist
import portability/application/queries/export_data/handler as export_data_handler
import portability/driver/dependencies.{type Dependencies}
import portability/driver/export_file
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

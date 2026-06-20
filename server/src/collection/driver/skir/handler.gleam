import collection/application/commands/import_collection/handler as import_collection_handler
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/handler as latest_status_handler
import collection/driver/skir/codec as collection_skir_codec
import composition.{type Dependencies}
import gleam/list
import skir/skirout/collection/commands as collection_commands
import skir/skirout/collection/queries as collection_queries
import skir_client/service

pub fn register(
  svc: service.Service(Nil, Dependencies, Nil),
) -> service.Service(Nil, Dependencies, Nil) {
  svc
  |> service.add_method(
    collection_commands.import_collection_method(),
    handle_import_collection,
  )
  |> service.add_method(
    collection_queries.get_latest_import_status_method(),
    handle_get_latest_import_status,
  )
}

fn handle_import_collection(
  req: collection_commands.ImportCollectionRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(collection_commands.ImportCollectionResponse, service.ServiceError),
  Nil,
  Nil,
) {
  let result =
    import_collection_handler.execute(
      import_collection_handler.ImportCollectionCommand(
        import_run_id: req.import_run_id,
        source_name: req.source_name,
        source_checksum: req.source_checksum,
        row_count: req.row_count,
        rows: list.map(req.rows, map_import_collection_row),
      ),
      deps.import_collection_ports,
    )
  #(collection_skir_codec.map_import_collection_result(result), req_meta, Nil)
}

fn handle_get_latest_import_status(
  _: collection_queries.GetLatestImportStatusRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(Result(collection_queries.ImportStatus, service.ServiceError), Nil, Nil) {
  let result =
    latest_status_handler.execute(
      latest_status_handler.LatestImportStatusQuery,
      deps.latest_import_status_port,
    )
  #(
    collection_skir_codec.map_get_latest_import_status_result(result),
    req_meta,
    Nil,
  )
}

fn map_import_collection_row(
  row: collection_commands.ImportCollectionRow,
) -> import_collection_ports.ImportCollectionRow {
  import_collection_ports.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

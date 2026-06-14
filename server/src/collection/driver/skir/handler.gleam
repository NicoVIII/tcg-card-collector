import collection/application/handler as collection_handler
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
  collection_handler.import_collection(
    deps.import_collection_port,
    req.import_run_id,
    req.source_name,
    req.source_checksum,
    req.row_count,
    list.map(req.rows, map_import_collection_row),
  )
  |> fn(response) {
    case response {
      collection_handler.Accepted -> #(
        Ok(collection_commands.ImportCollectionResponseAccepted),
        req_meta,
        Nil,
      )
      collection_handler.Rejected -> #(
        Ok(collection_commands.ImportCollectionResponseRejected),
        req_meta,
        Nil,
      )
    }
  }
}

fn handle_get_latest_import_status(
  _: collection_queries.GetLatestImportStatusRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(Result(collection_queries.ImportStatus, service.ServiceError), Nil, Nil) {
  let response =
    collection_handler.get_latest_import_status(deps.latest_import_status_port)

  case response {
    collection_handler.ImportStatusFound(run) -> #(
      Ok(collection_queries.import_status_new(
        run.id,
        run.row_count,
        run.source_name,
        collection_handler.status_to_string(run.status),
      )),
      req_meta,
      Nil,
    )
    collection_handler.ImportStatusNotFound -> #(
      Error(service.ServiceError(
        service.E404xNotFound,
        "import status not found",
      )),
      req_meta,
      Nil,
    )
  }
}

fn map_import_collection_row(
  row: collection_commands.ImportCollectionRow,
) -> collection_handler.ImportCollectionRow {
  collection_handler.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

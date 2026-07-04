import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/ports as latest_status_ports
import collection/domain/import_mode
import collection/domain/import_status
import gleam/option.{type Option, None, Some}
import shared/driver/skir/skirout/collection/commands as collection_commands
import shared/driver/skir/skirout/collection/queries as collection_queries
import skir_client/service

pub fn parse_import_mode(
  wire: collection_commands.ImportMode,
) -> Result(import_mode.ImportMode, Nil) {
  case wire {
    collection_commands.ImportModeFull -> Ok(import_mode.Full)
    collection_commands.ImportModeDelta -> Ok(import_mode.Delta)
    collection_commands.ImportModeUnknown(_) -> Error(Nil)
  }
}

pub fn map_import_collection_result(
  result: Result(Nil, import_collection_ports.ImportCollectionError),
) -> Result(collection_commands.ImportCollectionResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.ImportCollectionResponseAccepted)
    Error(_) -> Ok(collection_commands.ImportCollectionResponseRejected)
  }
}

pub fn map_get_latest_import_status_result(
  result: Option(latest_status_ports.ImportRunReadModel),
) -> Result(collection_queries.ImportStatus, service.ServiceError) {
  case result {
    Some(run) ->
      Ok(collection_queries.import_status_new(
        run.id,
        run.row_count,
        run.source_name,
        import_status.to_string(run.status),
      ))
    None ->
      Error(service.ServiceError(
        service.E404xNotFound,
        "import status not found",
      ))
  }
}

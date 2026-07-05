import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/ports as latest_status_ports
import collection/domain/import_status
import gleam/option.{type Option, None, Some}
import shared/driver/skir/skirout/collection/commands as collection_commands
import shared/driver/skir/skirout/collection/queries as collection_queries
import skir_client/service

pub fn map_import_collection_result(
  result: Result(Nil, import_collection_ports.ImportCollectionError),
) -> Result(collection_commands.ImportCollectionResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.ImportCollectionResponseAccepted)
    Error(import_collection_ports.RowCountMismatch) ->
      Ok(collection_commands.ImportCollectionResponseRejected)
    Error(import_collection_ports.PersistenceFailed(reason)) ->
      Error(service.ServiceError(service.E500xInternalServerError, reason))
  }
}

pub fn map_add_cards_result(
  result: Result(Nil, add_cards_ports.AddCardsError),
) -> Result(collection_commands.AddCardsResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.AddCardsResponseAdded)
    Error(add_cards_ports.InvalidRows) ->
      Ok(collection_commands.AddCardsResponseRejected)
    Error(add_cards_ports.PersistenceFailed(reason)) ->
      Error(service.ServiceError(service.E500xInternalServerError, reason))
  }
}

pub fn map_get_latest_import_status_result(
  result: Result(Option(latest_status_ports.ImportRunReadModel), String),
) -> Result(collection_queries.ImportStatus, service.ServiceError) {
  case result {
    Ok(Some(run)) ->
      Ok(collection_queries.import_status_new(
        run.id,
        run.row_count,
        run.source_name,
        import_status.to_string(run.status),
      ))
    Ok(None) ->
      Error(service.ServiceError(
        service.E404xNotFound,
        "import status not found",
      ))
    Error(reason) ->
      Error(service.ServiceError(service.E500xInternalServerError, reason))
  }
}

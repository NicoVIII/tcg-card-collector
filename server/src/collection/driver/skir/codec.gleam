import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import shared/driver/skir/skirout/collection/commands as collection_commands
import skir_client/service

pub fn map_import_collection_result(
  result: Result(Nil, import_collection_ports.ImportCollectionError),
) -> Result(collection_commands.ImportCollectionResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.ImportCollectionResponseAccepted)
    Error(import_collection_ports.InvalidRows) ->
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

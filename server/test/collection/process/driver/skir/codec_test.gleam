import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/driver/skir/codec as collection_skir_codec
import shared/driver/skir/skirout/collection/commands as collection_commands
import skir_client/service

pub fn import_ok_maps_to_accepted_test() {
  assert collection_skir_codec.map_import_collection_result(Ok(Nil))
    == Ok(collection_commands.ImportCollectionResponseAccepted)
}

pub fn import_invalid_rows_maps_to_rejected_test() {
  assert collection_skir_codec.map_import_collection_result(Error(
      import_collection_ports.InvalidRows,
    ))
    == Ok(collection_commands.ImportCollectionResponseRejected)
}

pub fn import_persistence_failed_maps_to_service_error_test() {
  assert collection_skir_codec.map_import_collection_result(
      Error(import_collection_ports.PersistenceFailed("db unavailable")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "db unavailable",
    ))
}

pub fn add_cards_ok_maps_to_added_test() {
  assert collection_skir_codec.map_add_cards_result(Ok(Nil))
    == Ok(collection_commands.AddCardsResponseAdded)
}

pub fn add_cards_invalid_rows_maps_to_rejected_test() {
  assert collection_skir_codec.map_add_cards_result(Error(
      add_cards_ports.InvalidRows,
    ))
    == Ok(collection_commands.AddCardsResponseRejected)
}

pub fn add_cards_persistence_failed_maps_to_service_error_test() {
  assert collection_skir_codec.map_add_cards_result(
      Error(add_cards_ports.PersistenceFailed("db unavailable")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "db unavailable",
    ))
}

import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/ports as latest_status_ports
import collection/domain/import_status
import collection/driver/skir/codec as collection_skir_codec
import gleam/option.{None, Some}
import shared/driver/skir/skirout/collection/commands as collection_commands
import skir_client/service

pub fn import_ok_maps_to_accepted_test() {
  assert collection_skir_codec.map_import_collection_result(Ok(Nil))
    == Ok(collection_commands.ImportCollectionResponseAccepted)
}

pub fn import_error_maps_to_rejected_test() {
  assert collection_skir_codec.map_import_collection_result(Error(
      import_collection_ports.RowCountMismatch,
    ))
    == Ok(collection_commands.ImportCollectionResponseRejected)
}

pub fn latest_status_found_maps_run_fields_test() {
  let run =
    latest_status_ports.ImportRunReadModel(
      id: "run-1",
      source_name: "test.csv",
      status: import_status.Succeeded,
      row_count: 3,
    )

  let assert Ok(mapped) =
    collection_skir_codec.map_get_latest_import_status_result(Some(run))

  assert mapped.import_run_id == "run-1"
  assert mapped.source_name == "test.csv"
  assert mapped.status == "succeeded"
  assert mapped.row_count == 3
}

pub fn latest_status_not_found_maps_to_not_found_test() {
  assert collection_skir_codec.map_get_latest_import_status_result(None)
    == Error(service.ServiceError(
      service.E404xNotFound,
      "import status not found",
    ))
}

import bootstrap/skir/skirout/card_catalog/commands as card_catalog_commands
import catalog/application/commands/refresh/ports as refresh_ports
import catalog/driver/skir/codec as catalog_skir_codec
import skir_client/service

pub fn ok_result_maps_to_response_success_test() {
  assert catalog_skir_codec.map_refresh_catalog_result(Ok(Nil))
    == Ok(card_catalog_commands.RefreshCatalogResponseSuccess)
}

pub fn error_result_maps_to_service_error_test() {
  assert catalog_skir_codec.map_refresh_catalog_result(
      Error(refresh_ports.RefreshCatalogError(reason: "some error")),
    )
    == Error(service.ServiceError(
      service.E503xServiceUnavailable,
      "catalog refresh failed",
    ))
}

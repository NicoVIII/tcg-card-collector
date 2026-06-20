import bootstrap/skir/skirout/card_catalog/commands as card_catalog_commands
import catalog/application/commands/refresh/ports as refresh_ports
import skir_client/service

pub fn map_refresh_catalog_result(
  result: Result(Nil, refresh_ports.RefreshCatalogError),
) -> Result(card_catalog_commands.RefreshCatalogResponse, service.ServiceError) {
  case result {
    Ok(Nil) -> Ok(card_catalog_commands.RefreshCatalogResponseSuccess)
    Error(_) ->
      Error(service.ServiceError(
        service.E503xServiceUnavailable,
        "catalog refresh failed",
      ))
  }
}

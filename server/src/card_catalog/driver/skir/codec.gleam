import card_catalog/application/queries/refresh_status/ports as refresh_status_ports
import card_catalog/driver/refresh_launcher.{
  RefreshAlreadyRunning, RefreshStarted,
}
import shared/driver/skir/skirout/card_catalog/commands as card_catalog_commands
import shared/driver/skir/skirout/card_catalog/queries as card_catalog_queries

pub fn map_refresh_launch_result(
  outcome: refresh_launcher.RefreshLaunchOutcome,
) -> card_catalog_commands.RefreshCatalogResponse {
  case outcome {
    RefreshStarted -> card_catalog_commands.RefreshCatalogResponseStarted
    RefreshAlreadyRunning ->
      card_catalog_commands.RefreshCatalogResponseAlreadyRunning
  }
}

pub fn map_refresh_status_result(
  status: refresh_status_ports.RefreshStatusReadModel,
) -> card_catalog_queries.CatalogRefreshStatus {
  // arg order: error_message, last_probe_at, last_upstream_updated_at, status
  // (alphabetical per generated constructor)
  card_catalog_queries.catalog_refresh_status_new(
    status.error_message,
    status.last_probe_at,
    status.last_upstream_updated_at,
    status.status,
  )
}

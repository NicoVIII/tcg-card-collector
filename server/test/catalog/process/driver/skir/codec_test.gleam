import catalog/application/queries/refresh_status/ports as refresh_status_ports
import catalog/driver/refresh_launcher
import catalog/driver/skir/codec as catalog_skir_codec
import shared/driver/skir/skirout/card_catalog/commands as card_catalog_commands

pub fn started_outcome_maps_to_response_started_test() {
  assert catalog_skir_codec.map_refresh_launch_result(
      refresh_launcher.RefreshStarted,
    )
    == card_catalog_commands.RefreshCatalogResponseStarted
}

pub fn already_running_outcome_maps_to_response_already_running_test() {
  assert catalog_skir_codec.map_refresh_launch_result(
      refresh_launcher.RefreshAlreadyRunning,
    )
    == card_catalog_commands.RefreshCatalogResponseAlreadyRunning
}

pub fn refresh_status_maps_fields_in_order_test() {
  let status =
    refresh_status_ports.RefreshStatusReadModel(
      status: "failed",
      last_probe_at: "2026-01-01T00:00:00Z",
      last_upstream_updated_at: "2025-12-31T00:00:00Z",
      error_message: "network error",
    )

  let mapped = catalog_skir_codec.map_refresh_status_result(status)

  assert mapped.status == "failed"
  assert mapped.last_probe_at == "2026-01-01T00:00:00Z"
  assert mapped.last_upstream_updated_at == "2025-12-31T00:00:00Z"
  assert mapped.error_message == "network error"
}

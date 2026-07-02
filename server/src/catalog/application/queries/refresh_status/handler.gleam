import catalog/application/queries/refresh_status/ports
import catalog/domain/refresh_record.{Failed, ProbeResult, Skipped, Succeeded}
import gleam/option.{None, Some}
import gleam/time/duration
import gleam/time/timestamp

pub type GetCatalogRefreshStatusQuery {
  GetCatalogRefreshStatusQuery
}

pub fn execute(
  _query: GetCatalogRefreshStatusQuery,
  port: ports.GetCatalogRefreshStatusPort,
) -> ports.RefreshStatusReadModel {
  case port.load_refresh_record() {
    None ->
      ports.RefreshStatusReadModel(
        status: "never_run",
        last_probe_at: "",
        last_upstream_updated_at: "",
        error_message: "",
      )
    Some(ProbeResult(last_probe_at:, last_upstream_updated_at:, status:)) -> {
      let probe_at_str =
        timestamp.to_rfc3339(last_probe_at, duration.seconds(0))
      let upstream_str = option.unwrap(last_upstream_updated_at, "")
      case status {
        Succeeded ->
          ports.RefreshStatusReadModel(
            status: "succeeded",
            last_probe_at: probe_at_str,
            last_upstream_updated_at: upstream_str,
            error_message: "",
          )
        Skipped ->
          ports.RefreshStatusReadModel(
            status: "skipped",
            last_probe_at: probe_at_str,
            last_upstream_updated_at: upstream_str,
            error_message: "",
          )
        Failed(reason) ->
          ports.RefreshStatusReadModel(
            status: "failed",
            last_probe_at: probe_at_str,
            last_upstream_updated_at: upstream_str,
            error_message: reason,
          )
      }
    }
  }
}

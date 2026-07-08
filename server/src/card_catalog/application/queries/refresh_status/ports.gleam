import card_catalog/domain/refresh_record.{type ProbeResult}
import gleam/option.{type Option}

pub type RefreshStatusReadModel {
  RefreshStatusReadModel(
    status: String,
    last_probe_at: String,
    last_upstream_updated_at: String,
    error_message: String,
  )
}

pub type LoadRefreshRecordPort =
  fn() -> Result(Option(ProbeResult), String)

pub type GetCatalogRefreshStatusPort {
  GetCatalogRefreshStatusPort(load_refresh_record: LoadRefreshRecordPort)
}

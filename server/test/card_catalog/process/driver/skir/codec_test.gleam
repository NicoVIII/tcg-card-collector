import card_catalog/application/queries/list_cards/ports as list_cards_ports
import card_catalog/application/queries/refresh_status/ports as refresh_status_ports
import card_catalog/driver/refresh_launcher
import card_catalog/driver/skir/codec as catalog_skir_codec
import gleam/list
import gleam/option.{None, Some}
import shared/domain/set_code
import shared/driver/skir/skirout/card_catalog/commands as card_catalog_commands
import shared/driver/skir/skirout/card_catalog/queries as card_catalog_queries

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

fn keys(
  collector_numbers: List(String),
) -> List(list_cards_ports.CatalogCardKeyReadModel) {
  list.map(collector_numbers, fn(collector_number) {
    list_cards_ports.CatalogCardKeyReadModel(set_code: "lea", collector_number:)
  })
}

fn collector_numbers(
  page: card_catalog_queries.CatalogCardKeyList,
) -> List(String) {
  list.map(page.data, fn(key: card_catalog_queries.CatalogCardKey) {
    key.collector_number
  })
}

pub fn key_page_slices_by_offset_and_limit_and_reports_full_total_test() {
  let page =
    catalog_skir_codec.map_catalog_card_key_page(
      keys(["1", "2", "3", "4", "5"]),
      1,
      2,
    )

  assert collector_numbers(page) == ["2", "3"]
  assert page.offset == 1
  assert page.limit == 2
  assert page.total == 5
}

pub fn key_page_with_zero_limit_returns_everything_after_offset_test() {
  let page =
    catalog_skir_codec.map_catalog_card_key_page(
      keys(["1", "2", "3", "4"]),
      2,
      0,
    )

  assert collector_numbers(page) == ["3", "4"]
}

pub fn key_page_treats_negative_offset_and_limit_as_zero_test() {
  let page =
    catalog_skir_codec.map_catalog_card_key_page(keys(["1", "2", "3"]), -1, -5)

  assert collector_numbers(page) == ["1", "2", "3"]
}

pub fn filter_trims_name_and_parses_set_code_test() {
  let req =
    card_catalog_queries.list_catalog_cards_request_new(
      limit: 0,
      name: Some(" Bolt "),
      offset: 0,
      set_code: Some(" LEA "),
    )

  let filter = catalog_skir_codec.to_catalog_card_filter(req)

  assert filter.name == Some("Bolt")
  let assert Ok(lea) = set_code.new("lea")
  assert filter.set_code == Some(lea)
}

pub fn filter_treats_blank_fields_as_absent_test() {
  let req =
    card_catalog_queries.list_catalog_cards_request_new(
      limit: 0,
      name: Some("   "),
      offset: 0,
      set_code: None,
    )

  let filter = catalog_skir_codec.to_catalog_card_filter(req)

  assert filter.name == None
  assert filter.set_code == None
}

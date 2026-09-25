import collection/driver/gleam/collection_api
import gleam/list
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import insights/driver/gleam/insights_api
import inventory_planning/driver/gleam/inventory_planning_api
import portability/application/queries/export_data/ports
import portability/domain/export_document

pub fn new() -> ports.ExportDataPorts {
  ports.ExportDataPorts(
    list_collection_entries: list_collection_entries_adapter(),
    list_target_sets: insights_api.list_target_sets,
    list_rules: list_rules_adapter(),
    get_bulk_spec: get_bulk_spec_adapter(),
    list_placed: list_placed_adapter(),
    today: today_adapter(),
  )
}

fn list_collection_entries_adapter() -> ports.ListCollectionEntriesPort {
  fn() {
    use copies <- result.try(collection_api.list_copies())
    Ok(
      list.map(copies, fn(copy) {
        export_document.CollectionEntry(key: copy.key, quantity: copy.quantity)
      }),
    )
  }
}

fn list_rules_adapter() -> ports.ListRulesPort {
  fn() {
    use rules <- result.try(inventory_planning_api.list_rules())
    Ok(
      list.map(rules, fn(rule) {
        export_document.Rule(
          location: rule.location,
          expression: rule.expression,
          selector: rule.selector,
          sort_keys: rule.sort_keys,
        )
      }),
    )
  }
}

fn get_bulk_spec_adapter() -> ports.GetBulkSpecPort {
  fn() {
    use spec <- result.map(inventory_planning_api.get_bulk_spec())
    export_document.BulkSpec(location: spec.location, sort_keys: spec.sort_keys)
  }
}

fn list_placed_adapter() -> ports.ListPlacedPort {
  fn() {
    use copies <- result.try(inventory_planning_api.list_placed())
    Ok(
      list.map(copies, fn(copy) {
        export_document.PlacedEntry(
          key: copy.key,
          location: copy.location,
          quantity: copy.quantity,
        )
      }),
    )
  }
}

fn today_adapter() -> ports.TodayPort {
  fn() {
    let #(date, _time) =
      timestamp.to_calendar(timestamp.system_time(), calendar.utc_offset)
    date
  }
}

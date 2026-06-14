import collection/application/queries/latest_status/ports as import_ports
import collection/domain/import_status
import gleam/dynamic/decode
import gleam/json
import gleam/result
import inventory_planning/application/queries/get_preferences/ports as preferences_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/projection/ports as projection_ports

// ---- Encoders ---------------------------------------------------------------

fn encode_import_run(run: import_ports.ImportRunReadModel) -> json.Json {
  json.object([
    #("id", json.string(run.id)),
    #("source_name", json.string(run.source_name)),
    #("status", json.string(import_status.to_string(run.status))),
    #("row_count", json.int(run.row_count)),
  ])
}

pub fn encode_import_status_found(
  run: import_ports.ImportRunReadModel,
) -> String {
  json.object([
    #("kind", json.string("found")),
    #("run", encode_import_run(run)),
  ])
  |> json.to_string
}

pub fn encode_import_status_not_found() -> String {
  json.object([#("kind", json.string("not_found"))])
  |> json.to_string
}

fn encode_inventory_rule(
  rule: list_rules_ports.InventoryRuleReadModel,
) -> json.Json {
  json.object([
    #("id", json.string(rule.id)),
    #("location_name", json.string(rule.location_name)),
    #("expression", json.string(rule.expression)),
  ])
}

pub fn encode_inventory_rules(
  rules: List(list_rules_ports.InventoryRuleReadModel),
) -> String {
  json.array(rules, of: encode_inventory_rule)
  |> json.to_string
}

fn encode_projection_row(
  row: projection_ports.InventoryProjectionReadModel,
) -> json.Json {
  json.object([
    #("location_name", json.string(row.location_name)),
    #("card_name", json.string(row.card_name)),
    #("set_code", json.string(row.set_code)),
    #("quantity", json.int(row.quantity)),
    #("group_value", json.string(row.group_value)),
  ])
}

pub fn encode_inventory_projection(
  rows: List(projection_ports.InventoryProjectionReadModel),
) -> String {
  json.array(rows, of: encode_projection_row)
  |> json.to_string
}

pub fn encode_settings(
  model: preferences_ports.PlanningPreferencesReadModel,
) -> String {
  json.object([
    #("default_sort", json.string(model.default_sort)),
    #("default_grouping", json.string(model.default_grouping)),
  ])
  |> json.to_string
}

pub fn encode_ok(msg: String) -> String {
  json.object([#("ok", json.string(msg))])
  |> json.to_string
}

pub fn encode_error(msg: String) -> String {
  json.object([#("error", json.string(msg))])
  |> json.to_string
}

// ---- Decoders ---------------------------------------------------------------

pub type ImportCollectionBody {
  ImportCollectionBody(
    import_run_id: String,
    source_name: String,
    source_checksum: String,
    row_count: Int,
  )
}

pub fn decode_import_collection_body(
  json_string: String,
) -> Result(ImportCollectionBody, String) {
  let decoder = {
    use import_run_id <- decode.field("import_run_id", decode.string)
    use source_name <- decode.field("source_name", decode.string)
    use source_checksum <- decode.field("source_checksum", decode.string)
    use row_count <- decode.field("row_count", decode.int)
    decode.success(ImportCollectionBody(
      import_run_id:,
      source_name:,
      source_checksum:,
      row_count:,
    ))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub type UpdateSettingsBody {
  UpdateSettingsBody(default_sort: String, default_grouping: String)
}

pub fn decode_update_settings_body(
  json_string: String,
) -> Result(UpdateSettingsBody, String) {
  let decoder = {
    use default_sort <- decode.field("default_sort", decode.string)
    use default_grouping <- decode.field("default_grouping", decode.string)
    decode.success(UpdateSettingsBody(default_sort:, default_grouping:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub type UpsertRuleBody {
  UpsertRuleBody(id: String, location_name: String, expression: String)
}

pub fn decode_upsert_rule_body(
  json_string: String,
) -> Result(UpsertRuleBody, String) {
  let decoder = {
    use id <- decode.field("id", decode.string)
    use location_name <- decode.field("location_name", decode.string)
    use expression <- decode.field("expression", decode.string)
    decode.success(UpsertRuleBody(id:, location_name:, expression:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub type DeleteRuleBody {
  DeleteRuleBody(id: String)
}

pub fn decode_delete_rule_body(
  json_string: String,
) -> Result(DeleteRuleBody, String) {
  let decoder = {
    use id <- decode.field("id", decode.string)
    decode.success(DeleteRuleBody(id:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

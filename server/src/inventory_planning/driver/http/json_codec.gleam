import gleam/dynamic/decode
import gleam/json
import gleam/result
import inventory_planning/application/queries/get_bulk_spec/ports as bulk_spec_ports
import inventory_planning/application/queries/get_preferences/ports as preferences_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placement_guidance/ports as placement_guidance_ports
import inventory_planning/application/queries/projection/ports as projection_ports

pub fn encode_inventory_rules(
  rules: List(list_rules_ports.InventoryRuleReadModel),
) -> String {
  json.array(rules, of: encode_inventory_rule)
  |> json.to_string
}

fn encode_inventory_rule(
  rule: list_rules_ports.InventoryRuleReadModel,
) -> json.Json {
  json.object([
    #("id", json.string(rule.id)),
    #("location_name", json.string(rule.location_name)),
    #("expression", json.string(rule.expression)),
    #("position", json.int(rule.position)),
    #("selector", json.string(rule.selector)),
    #("sort_keys", json.string(rule.sort_keys)),
  ])
}

pub fn encode_inventory_projection(
  projection: projection_ports.Projection,
) -> String {
  json.object([
    #("locations", json.array(projection.locations, of: encode_location)),
    #("total_quantity", json.int(projection.total_quantity)),
    #("unknown_count", json.int(projection.unknown_count)),
  ])
  |> json.to_string
}

fn encode_location(location: projection_ports.ProjectionLocation) -> json.Json {
  json.object([
    #("location_name", json.string(location.location_name)),
    #("rule_id", json.string(location.rule_id)),
    #("total_quantity", json.int(location.total_quantity)),
    #("cards", json.array(location.cards, of: encode_card)),
  ])
}

fn encode_card(card: projection_ports.ProjectionCard) -> json.Json {
  json.object([
    #("name", json.string(card.name)),
    #("set_code", json.string(card.set_code)),
    #("collector_number", json.string(card.collector_number)),
    #("quantity", json.int(card.quantity)),
    #("color_identity", json.string(card.color_identity)),
    #("rarity", json.string(card.rarity)),
    #("card_type", json.string(card.card_type)),
  ])
}

pub fn encode_placement_guidance(
  guidance: placement_guidance_ports.PlacementGuidance,
) -> String {
  json.object([
    #(
      "locations",
      json.array(guidance.locations, of: encode_placement_location),
    ),
    #("total_unplaced", json.int(guidance.total_unplaced)),
  ])
  |> json.to_string
}

fn encode_placement_location(
  location: placement_guidance_ports.PlacementLocation,
) -> json.Json {
  json.object([
    #("location_name", json.string(location.location_name)),
    #("total_quantity", json.int(location.total_quantity)),
    #("cards", json.array(location.cards, of: encode_placement_card)),
  ])
}

fn encode_placement_card(
  card: placement_guidance_ports.PlacementCard,
) -> json.Json {
  json.object([
    #("name", json.string(card.name)),
    #("set_code", json.string(card.set_code)),
    #("collector_number", json.string(card.collector_number)),
    #("to_place_quantity", json.int(card.to_place_quantity)),
    #("before", json.array(card.before, of: encode_placement_neighbor)),
    #("after", json.array(card.after, of: encode_placement_neighbor)),
  ])
}

fn encode_placement_neighbor(
  neighbor: placement_guidance_ports.PlacementNeighbor,
) -> json.Json {
  json.object([
    #("name", json.string(neighbor.name)),
    #("set_code", json.string(neighbor.set_code)),
    #("collector_number", json.string(neighbor.collector_number)),
    #("already_placed", json.bool(neighbor.already_placed)),
  ])
}

pub type PlacementBody {
  PlacementBody(
    set_code: String,
    collector_number: String,
    location_name: String,
    quantity: Int,
  )
}

pub fn decode_placements_body(
  json_string: String,
) -> Result(List(PlacementBody), String) {
  let placement_decoder = {
    use set_code <- decode.field("set_code", decode.string)
    use collector_number <- decode.field("collector_number", decode.string)
    use location_name <- decode.field("location_name", decode.string)
    use quantity <- decode.field("quantity", decode.int)
    decode.success(PlacementBody(
      set_code:,
      collector_number:,
      location_name:,
      quantity:,
    ))
  }
  let decoder = {
    use placements <- decode.field("placements", decode.list(placement_decoder))
    decode.success(placements)
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
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
  UpsertRuleBody(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
    sort_keys: String,
  )
}

pub fn decode_upsert_rule_body(
  json_string: String,
) -> Result(UpsertRuleBody, String) {
  let decoder = {
    use id <- decode.field("id", decode.string)
    use location_name <- decode.field("location_name", decode.string)
    use expression <- decode.field("expression", decode.string)
    use position <- decode.field("position", decode.int)
    use selector <- decode.field("selector", decode.string)
    use sort_keys <- decode.field("sort_keys", decode.string)
    decode.success(UpsertRuleBody(
      id:,
      location_name:,
      expression:,
      position:,
      selector:,
      sort_keys:,
    ))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub fn encode_bulk_spec(model: bulk_spec_ports.BulkSpecReadModel) -> String {
  json.object([
    #("location_name", json.string(model.location_name)),
    #("sort_keys", json.string(model.sort_keys)),
  ])
  |> json.to_string
}

pub type UpdateBulkSpecBody {
  UpdateBulkSpecBody(location_name: String, sort_keys: String)
}

pub fn decode_update_bulk_spec_body(
  json_string: String,
) -> Result(UpdateBulkSpecBody, String) {
  let decoder = {
    use location_name <- decode.field("location_name", decode.string)
    use sort_keys <- decode.field("sort_keys", decode.string)
    decode.success(UpdateBulkSpecBody(location_name:, sort_keys:))
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

import inventory_planning/application/queries/get_bulk_spec/ports as bulk_spec_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placement_guidance/ports as placement_guidance_ports
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/driver/http/json_codec

pub fn encode_inventory_projection_nests_locations_and_cards_test() {
  let projection =
    projection_ports.Projection(unknown_count: 1, total_quantity: 2, locations: [
      projection_ports.ProjectionLocation(
        location_name: "Bulk",
        rule_id: "",
        total_quantity: 2,
        cards: [
          projection_ports.ProjectionCard(
            name: "Grizzly Bears",
            set_code: "m11",
            collector_number: "182",
            quantity: 2,
            color_identity: "G",
            rarity: "common",
            card_type: "creature",
          ),
        ],
      ),
    ])

  assert json_codec.encode_inventory_projection(projection)
    == "{\"locations\":[{\"location_name\":\"Bulk\",\"rule_id\":\"\","
    <> "\"total_quantity\":2,\"cards\":[{\"name\":\"Grizzly Bears\","
    <> "\"set_code\":\"m11\",\"collector_number\":\"182\",\"quantity\":2,"
    <> "\"color_identity\":\"G\",\"rarity\":\"common\",\"card_type\":\"creature\"}]}],"
    <> "\"total_quantity\":2,\"unknown_count\":1}"
}

pub fn encode_placement_guidance_nests_locations_cards_and_neighbors_test() {
  let guidance =
    placement_guidance_ports.PlacementGuidance(total_unplaced: 1, locations: [
      placement_guidance_ports.PlacementLocation(
        location_name: "Bulk",
        total_quantity: 1,
        cards: [
          placement_guidance_ports.PlacementCard(
            name: "Grizzly Bears",
            set_code: "m11",
            collector_number: "182",
            to_place_quantity: 1,
            before: [
              placement_guidance_ports.PlacementNeighbor(
                name: "Lightning Bolt",
                set_code: "m11",
                collector_number: "146",
                already_placed: True,
              ),
            ],
            after: [],
          ),
        ],
      ),
    ])

  assert json_codec.encode_placement_guidance(guidance)
    == "{\"locations\":[{\"location_name\":\"Bulk\",\"total_quantity\":1,"
    <> "\"cards\":[{\"name\":\"Grizzly Bears\",\"set_code\":\"m11\","
    <> "\"collector_number\":\"182\",\"to_place_quantity\":1,"
    <> "\"before\":[{\"name\":\"Lightning Bolt\",\"set_code\":\"m11\","
    <> "\"collector_number\":\"146\",\"already_placed\":true}],\"after\":[]}]}],"
    <> "\"total_unplaced\":1}"
}

pub fn decode_placements_body_reads_the_placement_list_test() {
  let body =
    "{\"placements\":[{\"set_code\":\"lea\",\"collector_number\":\"1\","
    <> "\"location_name\":\"Bulk\",\"quantity\":2}]}"
  assert json_codec.decode_placements_body(body)
    == Ok([
      json_codec.PlacementBody(
        set_code: "lea",
        collector_number: "1",
        location_name: "Bulk",
        quantity: 2,
      ),
    ])
}

pub fn decode_placements_body_rejects_missing_placements_test() {
  assert json_codec.decode_placements_body("{}")
    == Error("invalid request body")
}

pub fn encode_inventory_rules_includes_position_selector_and_sort_keys_test() {
  let rules = [
    list_rules_ports.InventoryRuleReadModel(
      id: "r1",
      location_name: "Set binder {set_code}",
      expression: "set_code in (m11)",
      position: 3,
      selector: "first_per_oracle",
      sort_keys: "name,set_code",
    ),
  ]
  assert json_codec.encode_inventory_rules(rules)
    == "[{\"id\":\"r1\",\"location_name\":\"Set binder {set_code}\","
    <> "\"expression\":\"set_code in (m11)\",\"position\":3,"
    <> "\"selector\":\"first_per_oracle\",\"sort_keys\":\"name,set_code\"}]"
}

pub fn decode_upsert_rule_body_reads_position_selector_and_sort_keys_test() {
  let body =
    "{\"id\":\"r1\",\"location_name\":\"Bulk\",\"expression\":\"set_code=m11\","
    <> "\"position\":2,\"selector\":\"all\",\"sort_keys\":\"name\"}"
  assert json_codec.decode_upsert_rule_body(body)
    == Ok(json_codec.UpsertRuleBody(
      id: "r1",
      location_name: "Bulk",
      expression: "set_code=m11",
      position: 2,
      selector: "all",
      sort_keys: "name",
    ))
}

pub fn decode_upsert_rule_body_rejects_missing_sort_keys_test() {
  let body =
    "{\"id\":\"r1\",\"location_name\":\"Bulk\",\"expression\":\"set_code=m11\","
    <> "\"position\":2,\"selector\":\"all\"}"
  assert json_codec.decode_upsert_rule_body(body)
    == Error("invalid request body")
}

pub fn encode_bulk_spec_test() {
  let model =
    bulk_spec_ports.BulkSpecReadModel(
      location_name: "Bulk",
      sort_keys: "color_identity,type,name",
    )
  assert json_codec.encode_bulk_spec(model)
    == "{\"location_name\":\"Bulk\",\"sort_keys\":\"color_identity,type,name\"}"
}

pub fn decode_update_bulk_spec_body_test() {
  let body = "{\"location_name\":\"Overflow\",\"sort_keys\":\"name,set_code\"}"
  assert json_codec.decode_update_bulk_spec_body(body)
    == Ok(json_codec.UpdateBulkSpecBody(
      location_name: "Overflow",
      sort_keys: "name,set_code",
    ))
}

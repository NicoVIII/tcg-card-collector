import inventory_planning/application/queries/get_bulk_spec/ports as bulk_spec_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
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

pub fn encode_inventory_rules_includes_position_and_selector_test() {
  let rules = [
    list_rules_ports.InventoryRuleReadModel(
      id: "r1",
      location_name: "Set binder {set_code}",
      expression: "set_code in (m11)",
      position: 3,
      selector: "first_per_oracle",
    ),
  ]
  assert json_codec.encode_inventory_rules(rules)
    == "[{\"id\":\"r1\",\"location_name\":\"Set binder {set_code}\","
    <> "\"expression\":\"set_code in (m11)\",\"position\":3,"
    <> "\"selector\":\"first_per_oracle\"}]"
}

pub fn decode_upsert_rule_body_reads_position_and_selector_test() {
  let body =
    "{\"id\":\"r1\",\"location_name\":\"Bulk\",\"expression\":\"set_code=m11\","
    <> "\"position\":2,\"selector\":\"all\"}"
  assert json_codec.decode_upsert_rule_body(body)
    == Ok(json_codec.UpsertRuleBody(
      id: "r1",
      location_name: "Bulk",
      expression: "set_code=m11",
      position: 2,
      selector: "all",
    ))
}

pub fn decode_upsert_rule_body_rejects_missing_position_test() {
  let body =
    "{\"id\":\"r1\",\"location_name\":\"Bulk\",\"expression\":\"set_code=m11\"}"
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

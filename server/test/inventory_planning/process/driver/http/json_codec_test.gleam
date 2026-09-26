import inventory_planning/application/queries/get_bulk_spec/ports as bulk_spec_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placed_ledger/ports as placed_ledger_ports
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
            finish: "nonfoil",
            language: "en",
            quantity: 2,
            color_identity: "G",
            rarity: "common",
            card_type: "creature",
          ),
        ],
        sections: [
          projection_ports.ProjectionSection(
            parts: [
              projection_ports.ProjectionSectionPart(
                key: "color_identity",
                first: "G",
                last: "G",
              ),
            ],
            card_count: 2,
          ),
        ],
      ),
    ])

  assert json_codec.encode_inventory_projection(projection)
    == "{\"locations\":[{\"location_name\":\"Bulk\",\"rule_id\":\"\","
    <> "\"total_quantity\":2,\"cards\":[{\"name\":\"Grizzly Bears\","
    <> "\"set_code\":\"m11\",\"collector_number\":\"182\",\"finish\":\"nonfoil\","
    <> "\"language\":\"en\",\"quantity\":2,"
    <> "\"color_identity\":\"G\",\"rarity\":\"common\",\"card_type\":\"creature\"}],"
    <> "\"sections\":[{\"parts\":[{\"key\":\"color_identity\","
    <> "\"first\":\"G\",\"last\":\"G\"}],\"card_count\":2}]}],"
    <> "\"total_quantity\":2,\"unknown_count\":1}"
}

pub fn encode_placed_ledger_lists_rows_test() {
  let rows = [
    placed_ledger_ports.PlacedLedgerRow(
      set_code: "m11",
      collector_number: "182",
      finish: "nonfoil",
      language: "en",
      location: "Bulk",
      quantity: 3,
    ),
  ]

  assert json_codec.encode_placed_ledger(rows)
    == "{\"rows\":[{\"set_code\":\"m11\",\"collector_number\":\"182\","
    <> "\"finish\":\"nonfoil\",\"language\":\"en\","
    <> "\"location\":\"Bulk\",\"quantity\":3}]}"
}

pub fn decode_placements_body_reads_the_placement_list_test() {
  let body =
    "{\"placements\":[{\"set_code\":\"lea\",\"collector_number\":\"1\","
    <> "\"finish\":\"nonfoil\",\"language\":\"en\","
    <> "\"location_name\":\"Bulk\",\"quantity\":2}]}"
  assert json_codec.decode_placements_body(body)
    == Ok([
      json_codec.PlacementBody(
        set_code: "lea",
        collector_number: "1",
        finish: "nonfoil",
        language: "en",
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

pub fn decode_reorder_rules_body_test() {
  let body = "{\"ordered_ids\":[\"b\",\"a\"]}"
  assert json_codec.decode_reorder_rules_body(body)
    == Ok(json_codec.ReorderRulesBody(ordered_ids: ["b", "a"]))
}

pub fn decode_reorder_rules_body_rejects_missing_field_test() {
  assert json_codec.decode_reorder_rules_body("{}")
    == Error("invalid request body")
}

pub fn decode_relocate_placed_cards_body_test() {
  let body =
    "{\"from_location_name\":\"Box 1\",\"to_location_name\":\"Binder A\"}"
  assert json_codec.decode_relocate_placed_cards_body(body)
    == Ok(json_codec.RelocatePlacedCardsBody(
      from_location_name: "Box 1",
      to_location_name: "Binder A",
    ))
}

pub fn decode_relocate_placed_cards_body_rejects_missing_field_test() {
  assert json_codec.decode_relocate_placed_cards_body(
      "{\"from_location_name\":\"Box 1\"}",
    )
    == Error("invalid request body")
}

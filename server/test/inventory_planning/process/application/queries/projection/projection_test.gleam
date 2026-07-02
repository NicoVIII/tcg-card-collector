import gleam/dict
import gleam/list
import inventory_planning/application/queries/projection/handler
import inventory_planning/application/queries/projection/ports
import inventory_planning/domain/grouping_strategy
import inventory_planning/domain/sort_strategy

fn build_ports(
  snapshot_rows snapshot_rows: List(ports.SnapshotRow),
  rules rules: List(ports.RuleRow),
  catalog catalog: List(#(#(String, String), String)),
) -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: fn() { snapshot_rows },
    rules: fn() { rules },
    catalog_names: fn(keys) {
      catalog
      |> list.filter(fn(entry) { list.contains(keys, entry.0) })
      |> dict.from_list
    },
  )
}

pub fn batches_matched_rows_into_a_single_names_lookup_test() {
  let ports =
    build_ports(
      snapshot_rows: [
        ports.SnapshotRow(set_code: "abc", collector_number: "1", quantity: 2),
        ports.SnapshotRow(set_code: "abc", collector_number: "2", quantity: 3),
      ],
      rules: [ports.RuleRow(location_name: "Box 1", expression: "set_code=abc")],
      catalog: [
        #(#("abc", "1"), "Card One"),
        #(#("abc", "2"), "Card Two"),
      ],
    )

  let result =
    handler.execute(
      handler.InventoryProjectionQuery(
        sort_by: sort_strategy.ByCardName,
        group_by: grouping_strategy.ByLocation,
      ),
      ports,
    )

  assert result
    == [
      ports.InventoryProjectionReadModel(
        location_name: "Box 1",
        card_name: "Card One",
        set_code: "abc",
        quantity: 2,
        group_value: "Box 1",
      ),
      ports.InventoryProjectionReadModel(
        location_name: "Box 1",
        card_name: "Card Two",
        set_code: "abc",
        quantity: 3,
        group_value: "Box 1",
      ),
    ]
}

pub fn rows_with_no_matching_rule_are_dropped_test() {
  let ports =
    build_ports(
      snapshot_rows: [
        ports.SnapshotRow(
          set_code: "unmatched",
          collector_number: "1",
          quantity: 1,
        ),
      ],
      rules: [ports.RuleRow(location_name: "Box 1", expression: "set_code=abc")],
      catalog: [],
    )

  let result =
    handler.execute(
      handler.InventoryProjectionQuery(
        sort_by: sort_strategy.ByCardName,
        group_by: grouping_strategy.ByLocation,
      ),
      ports,
    )

  assert result == []
}

pub fn card_missing_from_catalog_gets_empty_name_test() {
  let ports =
    build_ports(
      snapshot_rows: [
        ports.SnapshotRow(set_code: "abc", collector_number: "1", quantity: 1),
      ],
      rules: [ports.RuleRow(location_name: "Box 1", expression: "set_code=abc")],
      catalog: [],
    )

  let result =
    handler.execute(
      handler.InventoryProjectionQuery(
        sort_by: sort_strategy.ByCardName,
        group_by: grouping_strategy.BySet,
      ),
      ports,
    )

  assert result
    == [
      ports.InventoryProjectionReadModel(
        location_name: "Box 1",
        card_name: "",
        set_code: "abc",
        quantity: 1,
        group_value: "abc",
      ),
    ]
}

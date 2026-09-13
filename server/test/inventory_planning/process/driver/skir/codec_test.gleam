import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_bulk_spec/ports as get_bulk_spec_ports
import inventory_planning/application/queries/get_preferences/ports as get_preferences_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placed_ledger/ports as placed_ledger_ports
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/driver/skir/codec as inventory_planning_skir_codec
import shared/driver/skir/skirout/inventory_planning/commands as inventory_planning_commands
import shared/driver/skir/skirout/inventory_planning/queries as inventory_planning_queries
import skir_client/service

pub fn map_projection_nests_locations_and_cards_test() {
  let projection =
    projection_ports.Projection(unknown_count: 2, total_quantity: 1, locations: [
      projection_ports.ProjectionLocation(
        location_name: "Rare binder R",
        rule_id: "r-rare",
        total_quantity: 1,
        cards: [
          projection_ports.ProjectionCard(
            name: "Lightning Bolt",
            set_code: "m11",
            collector_number: "146",
            quantity: 1,
            color_identity: "R",
            rarity: "rare",
            card_type: "instant",
          ),
        ],
      ),
    ])

  assert inventory_planning_skir_codec.map_projection(projection)
    == inventory_planning_queries.inventory_projection_new(
      [
        inventory_planning_queries.projection_location_new(
          [
            inventory_planning_queries.projection_card_new(
              "instant",
              "146",
              "R",
              "Lightning Bolt",
              1,
              "rare",
              "m11",
            ),
          ],
          "Rare binder R",
          "r-rare",
          1,
        ),
      ],
      1,
      2,
    )
}

pub fn map_placed_ledger_maps_rows_test() {
  let rows = [
    placed_ledger_ports.PlacedLedgerRow(
      set_code: "m11",
      collector_number: "146",
      location: "Bulk",
      quantity: 2,
    ),
  ]

  assert inventory_planning_skir_codec.map_placed_ledger(rows)
    == inventory_planning_queries.placed_ledger_new([
      inventory_planning_queries.placed_ledger_row_new("146", "Bulk", 2, "m11"),
    ])
}

pub fn mark_cards_placed_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_mark_cards_placed_result(Ok(Nil))
    == Ok(inventory_planning_commands.MarkCardsPlacedResponseSuccess)
}

pub fn mark_cards_placed_invalid_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_mark_cards_placed_result(Error(
      mark_cards_placed_ports.InvalidPlacements,
    ))
    == Error(service.ServiceError(service.E400xBadRequest, "invalid placements"))
}

pub fn mark_cards_placed_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_mark_cards_placed_result(
      Error(mark_cards_placed_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to mark cards placed",
    ))
}

pub fn unmark_cards_placed_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_unmark_cards_placed_result(Ok(Nil))
    == Ok(inventory_planning_commands.UnmarkCardsPlacedResponseSuccess)
}

pub fn unmark_cards_placed_invalid_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_unmark_cards_placed_result(Error(
      unmark_cards_placed_ports.InvalidPlacements,
    ))
    == Error(service.ServiceError(service.E400xBadRequest, "invalid placements"))
}

pub fn unmark_cards_placed_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_unmark_cards_placed_result(
      Error(unmark_cards_placed_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to unmark cards placed",
    ))
}

pub fn upsert_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(Ok(Nil))
    == Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess)
}

pub fn upsert_invalid_expression_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(Error(
      upsert_rule_ports.InvalidExpression,
    ))
    == Error(service.ServiceError(
      service.E400xBadRequest,
      "invalid inventory rule expression",
    ))
}

pub fn upsert_invalid_selector_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(Error(
      upsert_rule_ports.InvalidSelector,
    ))
    == Error(service.ServiceError(
      service.E400xBadRequest,
      "invalid inventory rule selector",
    ))
}

pub fn upsert_invalid_sort_keys_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(Error(
      upsert_rule_ports.InvalidSortKeys,
    ))
    == Error(service.ServiceError(
      service.E400xBadRequest,
      "invalid inventory rule sort keys",
    ))
}

pub fn upsert_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(
      Error(upsert_rule_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to save inventory rule",
    ))
}

pub fn update_bulk_spec_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_update_bulk_spec_result(Ok(Nil))
    == Ok(inventory_planning_commands.UpdateBulkSpecResponseSuccess)
}

pub fn update_bulk_spec_invalid_sort_keys_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_update_bulk_spec_result(Error(
      update_bulk_spec_ports.InvalidSortKeys,
    ))
    == Error(service.ServiceError(
      service.E400xBadRequest,
      "invalid bulk sort keys",
    ))
}

pub fn update_bulk_spec_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_update_bulk_spec_result(
      Error(update_bulk_spec_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to save bulk spec",
    ))
}

pub fn delete_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_delete_inventory_rule_result(Ok(Nil))
    == Ok(inventory_planning_commands.DeleteInventoryRuleResponseSuccess)
}

pub fn delete_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_delete_inventory_rule_result(
      Error(delete_rule_ports.DeleteInventoryRuleError("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to delete inventory rule",
    ))
}

pub fn update_preferences_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_update_preferences_result(Ok(Nil))
    == Ok(inventory_planning_commands.UpdatePlanningPreferencesResponseSuccess)
}

pub fn update_preferences_invalid_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_update_preferences_result(Error(
      update_preferences_ports.InvalidPreferences,
    ))
    == Error(service.ServiceError(service.E400xBadRequest, "invalid settings"))
}

pub fn update_preferences_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_update_preferences_result(
      Error(update_preferences_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to save settings",
    ))
}

pub fn map_inventory_rule_list_maps_fields_and_counts_rules_test() {
  let rule =
    list_rules_ports.InventoryRuleReadModel(
      id: "r1",
      location_name: "Binder {set_code}",
      expression: "rarity >= rare",
      position: 3,
      selector: "all",
      sort_keys: "name",
    )

  let mapped = inventory_planning_skir_codec.map_inventory_rule_list([rule])

  assert mapped.total == 1
  let assert [mapped_rule] = mapped.data
  assert mapped_rule.id == "r1"
  assert mapped_rule.location_name == "Binder {set_code}"
  assert mapped_rule.expression == "rarity >= rare"
  assert mapped_rule.position == 3
  assert mapped_rule.selector == "all"
  assert mapped_rule.sort_keys == "name"
}

pub fn map_planning_preferences_keeps_sort_and_grouping_apart_test() {
  let mapped =
    inventory_planning_skir_codec.map_planning_preferences(
      get_preferences_ports.PlanningPreferencesReadModel(
        default_sort: "name",
        default_grouping: "set",
      ),
    )

  assert mapped.default_sort == "name"
  assert mapped.default_grouping == "set"
}

pub fn map_bulk_spec_keeps_location_and_sort_keys_apart_test() {
  let mapped =
    inventory_planning_skir_codec.map_bulk_spec(
      get_bulk_spec_ports.BulkSpecReadModel(
        location_name: "Bulk box",
        sort_keys: "set_code",
      ),
    )

  assert mapped.location_name == "Bulk box"
  assert mapped.sort_keys == "set_code"
}

import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/placement_guidance/ports as placement_guidance_ports
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

pub fn map_placement_guidance_nests_locations_cards_and_neighbors_test() {
  let guidance =
    placement_guidance_ports.PlacementGuidance(total_unplaced: 1, locations: [
      placement_guidance_ports.PlacementLocation(
        location_name: "Bulk",
        total_quantity: 1,
        cards: [
          placement_guidance_ports.PlacementCard(
            name: "Lightning Bolt",
            set_code: "m11",
            collector_number: "146",
            to_place_quantity: 1,
            before: [
              placement_guidance_ports.PlacementNeighbor(
                name: "Ancestral Recall",
                set_code: "lea",
                collector_number: "48",
                already_placed: True,
              ),
            ],
            after: [],
          ),
        ],
      ),
    ])

  assert inventory_planning_skir_codec.map_placement_guidance(guidance)
    == inventory_planning_queries.placement_guidance_new(
      [
        inventory_planning_queries.placement_location_new(
          [
            inventory_planning_queries.placement_card_new(
              [],
              [
                inventory_planning_queries.placement_neighbor_new(
                  True,
                  "48",
                  "Ancestral Recall",
                  "lea",
                ),
              ],
              "146",
              "Lightning Bolt",
              "m11",
              1,
            ),
          ],
          "Bulk",
          1,
        ),
      ],
      1,
    )
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

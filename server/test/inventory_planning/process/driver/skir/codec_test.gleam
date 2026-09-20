import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/handler as mark_cards_placed_handler
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/relocate_placed_cards/ports as relocate_placed_cards_ports
import inventory_planning/application/commands/reorder_rules/ports as reorder_rules_ports
import inventory_planning/application/commands/unmark_cards_placed/handler as unmark_cards_placed_handler
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_bulk_spec/ports as get_bulk_spec_ports
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
            finish: "foil",
            language: "de",
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
              inventory_planning_queries.FinishFoil,
              inventory_planning_queries.LanguageDe,
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

// An unrecognized finish/language never reaches map_projection in practice
// (the projection handler only ever produces canonical strings), but the
// fallback to the wire's unknown variant is worth pinning directly.
pub fn map_projection_card_falls_back_to_unknown_for_unrecognized_strings_test() {
  let card =
    projection_ports.ProjectionCard(
      name: "",
      set_code: "xyz",
      collector_number: "1",
      finish: "prerelease-stamped",
      language: "elvish",
      quantity: 1,
      color_identity: "",
      rarity: "",
      card_type: "",
    )
  let projection =
    projection_ports.Projection(unknown_count: 0, total_quantity: 1, locations: [
      projection_ports.ProjectionLocation(
        location_name: "Bulk",
        rule_id: "",
        total_quantity: 1,
        cards: [card],
      ),
    ])

  let mapped = inventory_planning_skir_codec.map_projection(projection)
  let assert [location] = mapped.locations
  let assert [mapped_card] = location.cards
  assert mapped_card.finish == inventory_planning_queries.finish_unknown
  assert mapped_card.language == inventory_planning_queries.language_unknown
}

pub fn map_placed_ledger_maps_rows_test() {
  let rows = [
    placed_ledger_ports.PlacedLedgerRow(
      set_code: "m11",
      collector_number: "146",
      finish: "nonfoil",
      language: "en",
      location: "Bulk",
      quantity: 2,
    ),
  ]

  assert inventory_planning_skir_codec.map_placed_ledger(rows)
    == inventory_planning_queries.placed_ledger_new([
      inventory_planning_queries.placed_ledger_row_new(
        "146",
        inventory_planning_queries.FinishNonfoil,
        inventory_planning_queries.LanguageEn,
        "Bulk",
        2,
        "m11",
      ),
    ])
}

pub fn to_mark_raw_placement_maps_finish_and_language_test() {
  let placement =
    inventory_planning_commands.card_placement_new(
      collector_number: "146",
      finish: inventory_planning_commands.FinishFoil,
      language: inventory_planning_commands.LanguageJa,
      location_name: "Bulk",
      quantity: 2,
      set_code: "m11",
    )

  assert inventory_planning_skir_codec.to_mark_raw_placement(placement)
    == mark_cards_placed_handler.RawPlacement(
      set_code: "m11",
      collector_number: "146",
      finish: "foil",
      language: "ja",
      location_name: "Bulk",
      quantity: 2,
    )
}

pub fn to_unmark_raw_placement_maps_finish_and_language_test() {
  let placement =
    inventory_planning_commands.card_placement_new(
      collector_number: "146",
      finish: inventory_planning_commands.FinishEtched,
      language: inventory_planning_commands.LanguageRu,
      location_name: "Bulk",
      quantity: 1,
      set_code: "m11",
    )

  assert inventory_planning_skir_codec.to_unmark_raw_placement(placement)
    == unmark_cards_placed_handler.RawPlacement(
      set_code: "m11",
      collector_number: "146",
      finish: "etched",
      language: "ru",
      location_name: "Bulk",
      quantity: 1,
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

pub fn relocate_placed_cards_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_relocate_placed_cards_result(Ok(Nil))
    == Ok(inventory_planning_commands.RelocatePlacedCardsResponseSuccess)
}

pub fn relocate_placed_cards_invalid_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_relocate_placed_cards_result(Error(
      relocate_placed_cards_ports.InvalidRelocation,
    ))
    == Error(service.ServiceError(service.E400xBadRequest, "invalid relocation"))
}

pub fn relocate_placed_cards_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_relocate_placed_cards_result(
      Error(relocate_placed_cards_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to relocate placed cards",
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

pub fn reorder_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_reorder_inventory_rules_result(Ok(
      Nil,
    ))
    == Ok(inventory_planning_commands.ReorderInventoryRulesResponseSuccess)
}

pub fn reorder_not_a_permutation_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_reorder_inventory_rules_result(Error(
      reorder_rules_ports.NotAPermutation,
    ))
    == Error(service.ServiceError(
      service.E400xBadRequest,
      "rule order must list every existing rule exactly once",
    ))
}

pub fn reorder_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_reorder_inventory_rules_result(
      Error(reorder_rules_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to save rule order",
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

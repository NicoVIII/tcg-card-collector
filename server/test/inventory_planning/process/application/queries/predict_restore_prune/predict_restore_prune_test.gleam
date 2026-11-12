import gleam/dict
import gleam/option.{None, Some}
import inventory_planning/application/queries/predict_restore_prune/handler.{
  PredictRestorePruneQuery, PrunedRow,
}
import inventory_planning/application/queries/predict_restore_prune/ports
import inventory_planning/domain/location_ref.{Cascade, Managed}
import inventory_planning/domain/managed_location.{Deck, ManagedLocation}
import inventory_planning/domain/placed_ledger_reconciliation.{PlacedRow}
import inventory_planning/domain/plan_restore
import shared/domain/copy_key.{type CopyKey}

fn lea1() -> CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code: "lea",
      collector_number: "1",
      finish: "nonfoil",
      language: "en",
    )
  key
}

// The current state: a binder and a deck "Burn" each hold one lea 1.
fn current_ports() -> ports.PredictRestorePrunePorts {
  ports.PredictRestorePrunePorts(
    list_placed: fn() {
      Ok([
        PlacedRow(key: lea1(), location: Cascade("Binder"), quantity: 1),
        PlacedRow(key: lea1(), location: Managed("d1"), quantity: 1),
      ])
    },
    list_managed_locations: fn() {
      Ok([ManagedLocation("d1", "Burn", Deck, dict.new())])
    },
  )
}

fn owning(quantity: Int) -> dict.Dict(CopyKey, Int) {
  dict.from_list([#(lea1(), quantity)])
}

fn raw_placed(kind: String, location: String) -> plan_restore.RawPlaced {
  plan_restore.RawPlaced(
    set_code: "lea",
    collector_number: "1",
    finish: "nonfoil",
    language: "en",
    location_kind: kind,
    location:,
    quantity: 1,
  )
}

pub fn without_a_placed_section_the_current_ledger_is_pruned_test() {
  // arrange
  let query =
    PredictRestorePruneQuery(owned: owning(0), managed: None, placed: None)

  // act
  let result = handler.execute(query, current_ports())

  // assert
  assert result
    == Ok([
      PrunedRow(
        row: PlacedRow(key: lea1(), location: Cascade("Binder"), quantity: 1),
        location_name: "Binder",
      ),
      PrunedRow(
        row: PlacedRow(key: lea1(), location: Managed("d1"), quantity: 1),
        location_name: "Burn",
      ),
    ])
}

pub fn replacing_the_decks_drops_their_rows_instead_of_pruning_them_test() {
  // arrange
  let query =
    PredictRestorePruneQuery(owned: owning(0), managed: Some([]), placed: None)

  // act
  let result = handler.execute(query, current_ports())

  // assert
  assert result
    == Ok([
      PrunedRow(
        row: PlacedRow(key: lea1(), location: Cascade("Binder"), quantity: 1),
        location_name: "Binder",
      ),
    ])
}

pub fn a_placed_section_is_pruned_under_its_restored_deck_names_test() {
  // arrange
  let query =
    PredictRestorePruneQuery(
      owned: owning(1),
      managed: Some([
        plan_restore.RawManagedLocation(
          name: "Elves",
          kind: "deck",
          members: [],
        ),
      ]),
      placed: Some([
        raw_placed("managed", "Elves"),
        raw_placed("managed", "Elves"),
      ]),
    )

  // act
  let result = handler.execute(query, current_ports())

  // assert
  assert result
    == Ok([
      PrunedRow(
        row: PlacedRow(
          key: lea1(),
          location: Managed("imported-managed-0"),
          quantity: 1,
        ),
        location_name: "Elves",
      ),
    ])
}

pub fn a_placed_entry_naming_no_deck_is_an_invalid_plan_test() {
  // arrange
  let query =
    PredictRestorePruneQuery(
      owned: owning(1),
      managed: None,
      placed: Some([raw_placed("managed", "Nowhere")]),
    )

  // act
  let result = handler.execute(query, current_ports())

  // assert
  let assert Error(ports.InvalidPlan(_)) = result
}

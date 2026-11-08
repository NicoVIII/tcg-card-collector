import gleam/dict
import gleam/option.{None, Some}
import inventory_planning/application/commands/restore_plan/handler
import inventory_planning/application/commands/restore_plan/ports
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location
import support/ref

type Captured {
  Captured(
    rules: option.Option(List(ports.RuleWriteModel)),
    bulk: option.Option(ports.BulkSpecWriteModel),
    managed: option.Option(List(managed_location.ManagedLocation)),
    placed: option.Option(List(ports.PlacedWriteModel)),
  )
}

// One existing deck, "Burn" (id d1), for a placed entry to resolve against
// when the command restores no managed locations of its own.
fn recording_port(
  captured: ref.Ref(List(Captured)),
  result: Result(Nil, String),
) -> ports.RestorePlanPorts {
  ports.RestorePlanPorts(
    replace_plan: fn(rules, bulk, managed, placed) {
      ref.set(captured, [
        Captured(rules:, bulk:, managed:, placed:),
        ..ref.get(captured)
      ])
      result
    },
    list_managed_locations: fn() {
      Ok([
        managed_location.ManagedLocation(
          id: "d1",
          name: "Burn",
          kind: managed_location.Deck,
          members: dict.new(),
        ),
      ])
    },
  )
}

fn a_rule(location: String, expression: String) -> handler.RawRule {
  handler.RawRule(
    location_name: location,
    expression:,
    selector: "all",
    sort_keys: "",
  )
}

fn empty_command() -> handler.RestorePlanCommand {
  handler.RestorePlanCommand(
    rules: None,
    bulk: None,
    managed: None,
    placed: None,
  )
}

pub fn absent_sections_are_passed_through_as_none_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let result = handler.execute(empty_command(), port)

  assert result == Ok(Nil)
  assert ref.get(captured)
    == [Captured(rules: None, bulk: None, managed: None, placed: None)]
}

pub fn valid_rules_get_deterministic_imported_ids_and_positions_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let assert Ok(Nil) =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        rules: Some([
          a_rule("Binder A", "rarity >= mythic"),
          a_rule("Binder B", "rarity >= rare"),
        ]),
      ),
      port,
    )

  let assert [Captured(rules: Some(rules), ..)] = ref.get(captured)
  assert rules
    == [
      ports.RuleWriteModel(
        id: "imported-0",
        location_name: "Binder A",
        expression: "rarity >= mythic",
        position: 0,
        selector: "all",
        sort_keys: "",
      ),
      ports.RuleWriteModel(
        id: "imported-1",
        location_name: "Binder B",
        expression: "rarity >= rare",
        position: 1,
        selector: "all",
        sort_keys: "",
      ),
    ]
}

pub fn one_invalid_rule_rejects_the_whole_batch_without_writing_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let result =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        rules: Some([
          a_rule("Binder A", "rarity >= rare"),
          a_rule("Binder B", "not a real predicate"),
        ]),
      ),
      port,
    )

  assert result == Error(ports.InvalidRules)
  assert ref.get(captured) == []
}

pub fn a_valid_bulk_spec_canonicalizes_its_sort_keys_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let assert Ok(Nil) =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        bulk: Some(handler.RawBulkSpec(
          location_name: "Bulk",
          sort_keys: " name , set_code ",
        )),
      ),
      port,
    )

  let assert [Captured(bulk: Some(bulk), ..)] = ref.get(captured)
  assert bulk
    == ports.BulkSpecWriteModel(
      location_name: "Bulk",
      sort_keys: "name,set_code",
    )
}

pub fn an_invalid_bulk_sort_key_is_rejected_without_writing_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let result =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        bulk: Some(handler.RawBulkSpec(
          location_name: "Bulk",
          sort_keys: "power",
        )),
      ),
      port,
    )

  assert result == Error(ports.InvalidBulkSpec)
  assert ref.get(captured) == []
}

pub fn placed_entries_sharing_a_key_and_location_are_merged_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))
  let raw =
    handler.RawPlaced(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
      location_kind: "cascade",
      location: "Box A",
      quantity: 1,
    )

  let assert Ok(Nil) =
    handler.execute(
      handler.RestorePlanCommand(..empty_command(), placed: Some([raw, raw])),
      port,
    )

  let assert [Captured(placed: Some([only]), ..)] = ref.get(captured)
  assert only.location == location_ref.Cascade("Box A")
  assert only.quantity == 2
}

pub fn an_invalid_placed_entry_rejects_the_whole_batch_without_writing_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let result =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        placed: Some([
          handler.RawPlaced(
            set_code: "mh2",
            collector_number: "17",
            finish: "foill",
            language: "en",
            location_kind: "cascade",
            location: "Box A",
            quantity: 1,
          ),
        ]),
      ),
      port,
    )

  assert result == Error(ports.InvalidPlaced)
  assert ref.get(captured) == []
}

pub fn a_persistence_failure_propagates_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Error("db down"))

  let result = handler.execute(empty_command(), port)

  assert result == Error(ports.PersistenceFailed("db down"))
}

fn a_raw_member(quantity: Int) -> handler.RawMember {
  handler.RawMember(
    set_code: "mh2",
    collector_number: "17",
    finish: "foil",
    language: "en",
    quantity:,
  )
}

fn a_placed_in_deck(name: String) -> handler.RawPlaced {
  handler.RawPlaced(
    set_code: "mh2",
    collector_number: "17",
    finish: "foil",
    language: "en",
    location_kind: "managed",
    location: name,
    quantity: 1,
  )
}

// A restore assigns fresh ids, so a placed entry names its deck and is
// resolved to the id this same restore gave it.
pub fn restored_decks_get_fresh_ids_and_placed_entries_resolve_to_them_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let assert Ok(Nil) =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        managed: Some([
          handler.RawManagedLocation(name: " Elves ", kind: "deck", members: [
            a_raw_member(1),
            a_raw_member(2),
          ]),
        ]),
        placed: Some([a_placed_in_deck("Elves")]),
      ),
      port,
    )

  let assert [Captured(managed: Some([deck]), placed: Some([placed]), ..)] =
    ref.get(captured)
  assert deck.id == "imported-managed-0"
  assert deck.name == "Elves"
  assert dict.values(deck.members) == [3]
  assert placed.location == location_ref.Managed("imported-managed-0")
}

pub fn without_restored_decks_a_placed_entry_resolves_against_existing_ones_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let assert Ok(Nil) =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        placed: Some([a_placed_in_deck("Burn")]),
      ),
      port,
    )

  let assert [Captured(placed: Some([placed]), ..)] = ref.get(captured)
  assert placed.location == location_ref.Managed("d1")
}

pub fn a_placed_entry_naming_an_unknown_deck_rejects_the_batch_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let result =
    handler.execute(
      handler.RestorePlanCommand(
        ..empty_command(),
        placed: Some([a_placed_in_deck("Nope")]),
      ),
      port,
    )

  assert result == Error(ports.InvalidPlaced)
  assert ref.get(captured) == []
}

pub fn two_restored_decks_sharing_a_name_are_rejected_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))
  let deck =
    handler.RawManagedLocation(name: "Elves", kind: "deck", members: [])

  let result =
    handler.execute(
      handler.RestorePlanCommand(..empty_command(), managed: Some([deck, deck])),
      port,
    )

  assert result == Error(ports.InvalidManagedLocations)
}

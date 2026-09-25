import gleam/option.{None, Some}
import inventory_planning/application/commands/restore_plan/handler
import inventory_planning/application/commands/restore_plan/ports
import support/ref

type Captured {
  Captured(
    rules: option.Option(List(ports.RuleWriteModel)),
    bulk: option.Option(ports.BulkSpecWriteModel),
    placed: option.Option(List(ports.PlacedWriteModel)),
  )
}

fn recording_port(
  captured: ref.Ref(List(Captured)),
  result: Result(Nil, String),
) -> ports.RestorePlanPorts {
  ports.RestorePlanPorts(replace_plan: fn(rules, bulk, placed) {
    ref.set(captured, [Captured(rules:, bulk:, placed:), ..ref.get(captured)])
    result
  })
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
  handler.RestorePlanCommand(rules: None, bulk: None, placed: None)
}

pub fn absent_sections_are_passed_through_as_none_test() {
  let captured = ref.new([])
  let port = recording_port(captured, Ok(Nil))

  let result = handler.execute(empty_command(), port)

  assert result == Ok(Nil)
  assert ref.get(captured) == [Captured(rules: None, bulk: None, placed: None)]
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
      location_name: "Box A",
      quantity: 1,
    )

  let assert Ok(Nil) =
    handler.execute(
      handler.RestorePlanCommand(..empty_command(), placed: Some([raw, raw])),
      port,
    )

  let assert [Captured(placed: Some([only]), ..)] = ref.get(captured)
  assert only.location == "Box A"
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
            location_name: "Box A",
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

import gleam/dict
import insights/application/queries/set_completion/handler
import insights/application/queries/set_completion/ports

fn build_ports(
  target_sets target_sets: List(String),
  catalog_keys catalog_keys: dict.Dict(String, List(String)),
  owned_cards owned_cards: List(ports.OwnedCard),
) -> ports.SetCompletionPorts {
  ports.SetCompletionPorts(
    target_sets: fn() { Ok(target_sets) },
    set_card_keys: fn(_set_codes) { Ok(catalog_keys) },
    owned_cards: fn() { Ok(owned_cards) },
  )
}

pub fn counts_owned_cards_against_the_catalog_denominator_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1", "2", "3"])]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "2"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([ports.SetCompletionReadModel(set_code: "lea", owned: 2, total: 3)])
}

pub fn duplicate_owned_rows_are_deduplicated_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1"])]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: 1)])
}

pub fn set_absent_from_the_catalog_returns_zero_total_test() {
  let ports =
    build_ports(
      target_sets: ["unknown"],
      catalog_keys: dict.new(),
      owned_cards: [],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "unknown", owned: 0, total: 0),
    ])
}

pub fn owned_cards_outside_target_sets_are_ignored_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1"])]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "other_set", collector_number: "9"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: 1)])
}

pub fn owned_cards_failure_propagates_as_error_test() {
  let ports =
    ports.SetCompletionPorts(
      target_sets: fn() { Ok(["lea"]) },
      set_card_keys: fn(_set_codes) { Ok(dict.from_list([#("lea", ["1"])])) },
      owned_cards: fn() { Error("db unavailable") },
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result == Error("db unavailable")
}

pub fn target_sets_failure_propagates_as_error_test() {
  let ports =
    ports.SetCompletionPorts(
      target_sets: fn() { Error("target_sets unreadable") },
      set_card_keys: fn(_set_codes) { Ok(dict.new()) },
      owned_cards: fn() { Ok([]) },
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result == Error("target_sets unreadable")
}

pub fn set_card_keys_failure_propagates_as_error_test() {
  let ports =
    ports.SetCompletionPorts(
      target_sets: fn() { Ok(["lea"]) },
      set_card_keys: fn(_set_codes) { Error("catalog unreadable") },
      owned_cards: fn() { Ok([]) },
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result == Error("catalog unreadable")
}

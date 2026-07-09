import gleam/dict
import gleam/option.{None, Some}
import insights/application/queries/set_completion/handler
import insights/application/queries/set_completion/ports

fn build_ports(
  target_sets target_sets: List(String),
  catalog_keys catalog_keys: dict.Dict(String, List(String)),
  printed_sizes printed_sizes: dict.Dict(String, option.Option(Int)),
  owned_cards owned_cards: List(ports.OwnedCard),
) -> ports.SetCompletionPorts {
  ports.SetCompletionPorts(
    target_sets: fn() { Ok(target_sets) },
    set_card_keys: fn(_set_codes) { Ok(catalog_keys) },
    printed_sizes: fn(_set_codes) { Ok(printed_sizes) },
    owned_cards: fn() { Ok(owned_cards) },
  )
}

pub fn total_is_the_printed_size_not_the_catalog_count_test() {
  // Catalog has 4 rows (incl. one extra numbered 4), but the official set is 3.
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1", "2", "3", "4"])]),
      printed_sizes: dict.from_list([#("lea", Some(3))]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "2"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 2, total: Some(3)),
    ])
}

pub fn owned_extras_above_printed_size_do_not_count_test() {
  // Owns card 4, which is an extra beyond the official size 3 — excluded so the
  // ratio can never exceed the denominator.
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1", "2", "3", "4"])]),
      printed_sizes: dict.from_list([#("lea", Some(3))]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "4"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: Some(3)),
    ])
}

pub fn owned_non_numeric_collector_numbers_are_extras_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1", "2", "2b"])]),
      printed_sizes: dict.from_list([#("lea", Some(2))]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "2b"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: Some(2)),
    ])
}

pub fn missing_printed_size_reports_owned_without_a_denominator_test() {
  // No official size: count all owned cards in the set (incl. the extra) and
  // report no total.
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1", "2", "99"])]),
      printed_sizes: dict.from_list([#("lea", None)]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "99"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 2, total: None),
    ])
}

pub fn set_absent_from_printed_sizes_has_no_denominator_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1"])]),
      printed_sizes: dict.new(),
      owned_cards: [ports.OwnedCard(set_code: "lea", collector_number: "1")],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: None),
    ])
}

pub fn duplicate_owned_rows_are_deduplicated_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1"])]),
      printed_sizes: dict.from_list([#("lea", Some(1))]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: Some(1)),
    ])
}

pub fn owned_cards_outside_target_sets_are_ignored_test() {
  let ports =
    build_ports(
      target_sets: ["lea"],
      catalog_keys: dict.from_list([#("lea", ["1"])]),
      printed_sizes: dict.from_list([#("lea", Some(1))]),
      owned_cards: [
        ports.OwnedCard(set_code: "lea", collector_number: "1"),
        ports.OwnedCard(set_code: "other_set", collector_number: "9"),
      ],
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result
    == Ok([
      ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: Some(1)),
    ])
}

pub fn owned_cards_failure_propagates_as_error_test() {
  let ports =
    ports.SetCompletionPorts(
      target_sets: fn() { Ok(["lea"]) },
      set_card_keys: fn(_set_codes) { Ok(dict.from_list([#("lea", ["1"])])) },
      printed_sizes: fn(_set_codes) { Ok(dict.from_list([#("lea", Some(1))])) },
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
      printed_sizes: fn(_set_codes) { Ok(dict.new()) },
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
      printed_sizes: fn(_set_codes) { Ok(dict.new()) },
      owned_cards: fn() { Ok([]) },
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result == Error("catalog unreadable")
}

pub fn printed_sizes_failure_propagates_as_error_test() {
  let ports =
    ports.SetCompletionPorts(
      target_sets: fn() { Ok(["lea"]) },
      set_card_keys: fn(_set_codes) { Ok(dict.from_list([#("lea", ["1"])])) },
      printed_sizes: fn(_set_codes) { Error("sets unreadable") },
      owned_cards: fn() { Ok([]) },
    )

  let result = handler.execute(handler.SetCompletionQuery, ports)

  assert result == Error("sets unreadable")
}

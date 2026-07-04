import gleam/dict
import insights/application/queries/set_completion/handler
import insights/application/queries/set_completion/ports

fn build_ports(
  target_sets target_sets: List(String),
  catalog_keys catalog_keys: dict.Dict(String, List(String)),
  owned_cards owned_cards: List(ports.OwnedCard),
) -> ports.SetCompletionPorts {
  ports.SetCompletionPorts(
    target_sets: fn() { target_sets },
    set_card_keys: fn(_set_codes) { catalog_keys },
    owned_cards: fn() { owned_cards },
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
    == [ports.SetCompletionReadModel(set_code: "lea", owned: 2, total: 3)]
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
    == [ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: 1)]
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
    == [ports.SetCompletionReadModel(set_code: "unknown", owned: 0, total: 0)]
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
    == [ports.SetCompletionReadModel(set_code: "lea", owned: 1, total: 1)]
}

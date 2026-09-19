import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import inventory_planning/application/commands/reconcile_placed_ledger/handler
import inventory_planning/application/commands/reconcile_placed_ledger/ports
import inventory_planning/domain/placed_ledger_reconciliation.{
  type PlacedRow, PlacedRow,
}
import shared/domain/copy_key.{type CopyKey}
import support/ref

fn key(set_code: String, collector_number: String) -> CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code:,
      collector_number:,
      finish: "nonfoil",
      language: "en",
    )
  key
}

fn build_ports(
  owned owned: Result(Dict(CopyKey, Int), String),
  placed placed: Result(List(PlacedRow), String),
  pruned pruned: ref.Ref(Option(List(PlacedRow))),
) -> ports.ReconcilePlacedLedgerPorts {
  ports.ReconcilePlacedLedgerPorts(
    owned_quantities: fn() { owned },
    list_placed: fn() { placed },
    decrement_placed: fn(rows) {
      ref.set(pruned, Some(rows))
      Ok(Nil)
    },
  )
}

pub fn a_key_within_bounds_prunes_nothing_test() {
  let lea1 = key("lea", "1")
  let pruned = ref.new(None)
  let command_ports =
    build_ports(
      owned: Ok(dict.from_list([#(lea1, 3)])),
      placed: Ok([PlacedRow(key: lea1, location: "Bulk", quantity: 3)]),
      pruned:,
    )

  let result =
    handler.execute(handler.ReconcilePlacedLedgerCommand, command_ports)

  assert result == Ok(Nil)
  assert ref.get(pruned) == Some([])
}

pub fn excess_is_pruned_through_to_the_port_test() {
  let lea1 = key("lea", "1")
  let pruned = ref.new(None)
  let command_ports =
    build_ports(
      owned: Ok(dict.from_list([#(lea1, 1)])),
      placed: Ok([PlacedRow(key: lea1, location: "Bulk", quantity: 3)]),
      pruned:,
    )

  let result =
    handler.execute(handler.ReconcilePlacedLedgerCommand, command_ports)

  assert result == Ok(Nil)
  assert ref.get(pruned)
    == Some([PlacedRow(key: lea1, location: "Bulk", quantity: 2)])
}

pub fn owned_quantities_failure_surfaces_and_skips_the_rest_test() {
  let pruned = ref.new(None)
  let command_ports =
    build_ports(owned: Error("catalog unavailable"), placed: Ok([]), pruned:)

  let result =
    handler.execute(handler.ReconcilePlacedLedgerCommand, command_ports)

  assert result == Error(ports.PersistenceFailed("catalog unavailable"))
  assert ref.get(pruned) == None
}

pub fn list_placed_failure_surfaces_test() {
  let pruned = ref.new(None)
  let command_ports =
    build_ports(owned: Ok(dict.new()), placed: Error("db down"), pruned:)

  let result =
    handler.execute(handler.ReconcilePlacedLedgerCommand, command_ports)

  assert result == Error(ports.PersistenceFailed("db down"))
  assert ref.get(pruned) == None
}

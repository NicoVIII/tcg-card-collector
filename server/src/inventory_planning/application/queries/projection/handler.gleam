import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/string
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/domain/grouping_strategy
import inventory_planning/domain/rule_expression
import inventory_planning/domain/rule_set
import inventory_planning/domain/sort_strategy

pub type InventoryProjectionQuery {
  InventoryProjectionQuery(
    sort_by: sort_strategy.SortStrategy,
    group_by: grouping_strategy.GroupingStrategy,
  )
}

pub fn execute(
  query: InventoryProjectionQuery,
  ports: projection_ports.InventoryProjectionPorts,
) -> Result(List(projection_ports.InventoryProjectionReadModel), String) {
  let InventoryProjectionQuery(sort_by: sort_by, group_by: group_by) = query

  let raw_rules = ports.rules()
  let rules =
    list.filter_map(raw_rules, fn(r) {
      case rule_expression.parse(r.expression) {
        Error(_) -> Error(Nil)
        Ok(expr) ->
          Ok(rule_set.InventoryRule(
            location_name: r.location_name,
            expression: expr,
          ))
      }
    })

  use snapshot_rows <- result.try(ports.snapshot_rows())

  let matched_rows =
    snapshot_rows
    |> list.filter_map(fn(row) {
      case rule_set.location_for(rules, row.set_code) {
        None -> Error(Nil)
        Some(location_name) -> Ok(#(row, location_name))
      }
    })

  let names =
    ports.catalog_names(
      list.map(matched_rows, fn(pair) {
        let #(row, _) = pair
        #(row.set_code, row.collector_number)
      }),
    )

  matched_rows
  |> list.map(fn(pair) {
    let #(row, location_name) = pair
    let card_name =
      dict.get(names, #(row.set_code, row.collector_number))
      |> result.unwrap("")
    let group_value = case group_by {
      grouping_strategy.BySet -> row.set_code
      grouping_strategy.ByLocation -> location_name
    }
    projection_ports.InventoryProjectionReadModel(
      location_name: location_name,
      card_name: card_name,
      set_code: row.set_code,
      quantity: row.quantity,
      group_value: group_value,
    )
  })
  |> sort_results(sort_by)
  |> Ok
}

fn sort_results(
  rows: List(projection_ports.InventoryProjectionReadModel),
  sort_by: sort_strategy.SortStrategy,
) -> List(projection_ports.InventoryProjectionReadModel) {
  list.sort(rows, fn(a, b) {
    let primary = case sort_by {
      sort_strategy.ByCardName -> string.compare(a.card_name, b.card_name)
      sort_strategy.BySetCode -> string.compare(a.set_code, b.set_code)
      sort_strategy.ByQuantity -> int.compare(a.quantity, b.quantity)
    }
    case primary {
      order.Eq -> string.compare(a.location_name, b.location_name)
      other -> other
    }
  })
}

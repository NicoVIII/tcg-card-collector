import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/string
import inventory_planning/application/queries/projection/ports
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
  port: ports.InventoryProjectionPort,
) -> List(ports.InventoryProjectionReadModel) {
  let InventoryProjectionQuery(sort_by: sort_by, group_by: group_by) = query

  let raw_rules = port.rules()
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

  port.snapshot_rows()
  |> list.filter_map(fn(row) {
    case rule_set.location_for(rules, row.set_code) {
      None -> Error(Nil)
      Some(location_name) -> {
        let card_name =
          port.catalog_name(row.set_code, row.collector_number)
          |> option.unwrap("")
        let group_value = case group_by {
          grouping_strategy.BySet -> row.set_code
          grouping_strategy.ByLocation -> location_name
        }
        Ok(ports.InventoryProjectionReadModel(
          location_name: location_name,
          card_name: card_name,
          set_code: row.set_code,
          quantity: row.quantity,
          group_value: group_value,
        ))
      }
    }
  })
  |> sort_results(sort_by)
}

fn sort_results(
  rows: List(ports.InventoryProjectionReadModel),
  sort_by: sort_strategy.SortStrategy,
) -> List(ports.InventoryProjectionReadModel) {
  list.sort(rows, fn(a, b) {
    let primary = case sort_by {
      sort_strategy.ByCardName -> string.compare(a.card_name, b.card_name)
      sort_strategy.BySetCode -> string.compare(a.set_code, b.set_code)
      sort_strategy.ByQuantity -> int_compare(a.quantity, b.quantity)
    }
    case primary {
      order.Eq -> string.compare(a.location_name, b.location_name)
      other -> other
    }
  })
}

fn int_compare(a: Int, b: Int) -> order.Order {
  case a < b {
    True -> order.Lt
    False ->
      case a > b {
        True -> order.Gt
        False -> order.Eq
      }
  }
}

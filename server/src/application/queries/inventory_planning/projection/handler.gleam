import application/queries/inventory_planning/projection/ports
import domain/inventory_planning/grouping_strategy
import domain/inventory_planning/sort_strategy

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
  port.projection(
    sort_strategy.to_string(sort_by),
    grouping_strategy.to_string(group_by),
  )
}

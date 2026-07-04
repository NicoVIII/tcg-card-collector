import inventory_planning/application/queries/get_bulk_spec/ports

pub type GetBulkSpecQuery {
  GetBulkSpecQuery
}

pub fn execute(
  _query: GetBulkSpecQuery,
  port: ports.GetBulkSpecPort,
) -> ports.BulkSpecReadModel {
  port.current()
}

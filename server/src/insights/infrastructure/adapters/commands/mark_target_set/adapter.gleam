import insights/application/commands/mark_target_set/ports
import insights/infrastructure/daos/insights_dao

pub fn new() -> ports.MarkTargetSetPort {
  ports.MarkTargetSetPort(mark: fn(set_code) { insights_dao.mark(set_code) })
}

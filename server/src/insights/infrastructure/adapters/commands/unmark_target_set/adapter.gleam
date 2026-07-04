import insights/application/commands/unmark_target_set/ports
import insights/infrastructure/daos/insights_dao

pub fn new() -> ports.UnmarkTargetSetPort {
  ports.UnmarkTargetSetPort(unmark: fn(set_code) {
    insights_dao.unmark(set_code)
  })
}

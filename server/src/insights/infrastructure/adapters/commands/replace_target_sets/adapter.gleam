import insights/application/commands/replace_target_sets/ports
import insights/infrastructure/daos/insights_dao

pub fn new() -> ports.ReplaceTargetSetsPort {
  ports.ReplaceTargetSetsPort(replace: insights_dao.replace)
}

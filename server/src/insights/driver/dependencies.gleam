import insights/application/commands/mark_target_set/ports as mark_target_set_ports
import insights/application/commands/unmark_target_set/ports as unmark_target_set_ports
import insights/application/queries/set_completion/ports as set_completion_ports

pub type Dependencies {
  Dependencies(
    mark_target_set_port: mark_target_set_ports.MarkTargetSetPort,
    unmark_target_set_port: unmark_target_set_ports.UnmarkTargetSetPort,
    set_completion_ports: set_completion_ports.SetCompletionPorts,
  )
}

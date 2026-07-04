import insights/application/commands/unmark_target_set/handler
import insights/application/commands/unmark_target_set/ports
import support/ref

fn build_port(
  unmarked unmarked: ref.Ref(List(String)),
  unmark_result unmark_result: Result(Nil, String),
) -> ports.UnmarkTargetSetPort {
  ports.UnmarkTargetSetPort(unmark: fn(set_code) {
    case unmark_result {
      Ok(Nil) -> {
        ref.set(unmarked, [set_code, ..ref.get(unmarked)])
        Ok(Nil)
      }
      Error(reason) -> Error(reason)
    }
  })
}

pub fn valid_set_code_is_unmarked_test() {
  let unmarked = ref.new([])
  let port = build_port(unmarked:, unmark_result: Ok(Nil))

  let result =
    handler.execute(handler.UnmarkTargetSetCommand(set_code: "lea"), port)

  assert result == Ok(Nil)
  assert ref.get(unmarked) == ["lea"]
}

pub fn blank_set_code_is_rejected_without_calling_the_port_test() {
  let unmarked = ref.new([])
  let port = build_port(unmarked:, unmark_result: Ok(Nil))

  let result =
    handler.execute(handler.UnmarkTargetSetCommand(set_code: ""), port)

  assert result == Error(ports.InvalidSetCode)
  assert ref.get(unmarked) == []
}

pub fn persistence_failure_is_reported_test() {
  let unmarked = ref.new([])
  let port = build_port(unmarked:, unmark_result: Error("disk full"))

  let result =
    handler.execute(handler.UnmarkTargetSetCommand(set_code: "lea"), port)

  assert result == Error(ports.PersistenceFailed("disk full"))
}

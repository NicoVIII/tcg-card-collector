import insights/application/commands/mark_target_set/handler
import insights/application/commands/mark_target_set/ports
import support/ref

fn build_port(
  marked marked: ref.Ref(List(String)),
  mark_result mark_result: Result(Nil, String),
) -> ports.MarkTargetSetPort {
  ports.MarkTargetSetPort(mark: fn(set_code) {
    case mark_result {
      Ok(Nil) -> {
        ref.set(marked, [set_code, ..ref.get(marked)])
        Ok(Nil)
      }
      Error(reason) -> Error(reason)
    }
  })
}

pub fn valid_set_code_is_marked_test() {
  let marked = ref.new([])
  let port = build_port(marked:, mark_result: Ok(Nil))

  let result =
    handler.execute(handler.MarkTargetSetCommand(set_code: "lea"), port)

  assert result == Ok(Nil)
  assert ref.get(marked) == ["lea"]
}

pub fn blank_set_code_is_rejected_without_calling_the_port_test() {
  let marked = ref.new([])
  let port = build_port(marked:, mark_result: Ok(Nil))

  let result = handler.execute(handler.MarkTargetSetCommand(set_code: ""), port)

  assert result == Error(ports.InvalidSetCode)
  assert ref.get(marked) == []
}

pub fn persistence_failure_is_reported_test() {
  let marked = ref.new([])
  let port = build_port(marked:, mark_result: Error("disk full"))

  let result =
    handler.execute(handler.MarkTargetSetCommand(set_code: "lea"), port)

  assert result == Error(ports.PersistenceFailed("disk full"))
}

import insights/application/commands/replace_target_sets/handler
import insights/application/commands/replace_target_sets/ports
import support/ref

fn build_port(
  replaced replaced: ref.Ref(List(List(String))),
  replace_result replace_result: Result(Nil, String),
) -> ports.ReplaceTargetSetsPort {
  ports.ReplaceTargetSetsPort(replace: fn(set_codes) {
    case replace_result {
      Ok(Nil) -> {
        ref.set(replaced, [set_codes, ..ref.get(replaced)])
        Ok(Nil)
      }
      Error(reason) -> Error(reason)
    }
  })
}

pub fn valid_set_codes_replace_the_whole_list_test() {
  let replaced = ref.new([])
  let port = build_port(replaced:, replace_result: Ok(Nil))

  let result =
    handler.execute(
      handler.ReplaceTargetSetsCommand(set_codes: ["lea", "2xm"]),
      port,
    )

  assert result == Ok(Nil)
  assert ref.get(replaced) == [["lea", "2xm"]]
}

pub fn empty_list_clears_every_target_test() {
  let replaced = ref.new([])
  let port = build_port(replaced:, replace_result: Ok(Nil))

  let result =
    handler.execute(handler.ReplaceTargetSetsCommand(set_codes: []), port)

  assert result == Ok(Nil)
  assert ref.get(replaced) == [[]]
}

pub fn a_blank_set_code_rejects_the_whole_batch_without_calling_the_port_test() {
  let replaced = ref.new([])
  let port = build_port(replaced:, replace_result: Ok(Nil))

  let result =
    handler.execute(
      handler.ReplaceTargetSetsCommand(set_codes: ["lea", ""]),
      port,
    )

  assert result == Error(ports.InvalidSetCodes)
  assert ref.get(replaced) == []
}

pub fn persistence_failure_is_reported_test() {
  let replaced = ref.new([])
  let port = build_port(replaced:, replace_result: Error("disk full"))

  let result =
    handler.execute(handler.ReplaceTargetSetsCommand(set_codes: ["lea"]), port)

  assert result == Error(ports.PersistenceFailed("disk full"))
}

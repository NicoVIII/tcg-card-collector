import gleam/option.{None, Some}
import insights/application/queries/set_completion/ports
import insights/driver/http/json_codec

pub fn decode_target_set_body_reads_set_code_test() {
  assert json_codec.decode_target_set_body("{\"set_code\":\"lea\"}")
    == Ok(json_codec.TargetSetBody(set_code: "lea"))
}

pub fn decode_target_set_body_rejects_missing_field_test() {
  assert json_codec.decode_target_set_body("{}")
    == Error("invalid request body")
}

pub fn encode_set_completion_writes_owned_and_total_test() {
  assert json_codec.encode_set_completion([
      ports.SetCompletionReadModel(set_code: "lea", owned: 2, total: Some(3)),
    ])
    == "[{\"set_code\":\"lea\",\"owned\":2,\"total\":3}]"
}

pub fn encode_set_completion_writes_null_total_when_absent_test() {
  assert json_codec.encode_set_completion([
      ports.SetCompletionReadModel(set_code: "lea", owned: 2, total: None),
    ])
    == "[{\"set_code\":\"lea\",\"owned\":2,\"total\":null}]"
}

import gleam/dynamic/decode
import gleam/json
import gleam/result
import insights/application/queries/set_completion/ports as set_completion_ports

pub type TargetSetBody {
  TargetSetBody(set_code: String)
}

pub fn decode_target_set_body(
  json_string: String,
) -> Result(TargetSetBody, String) {
  let decoder = {
    use set_code <- decode.field("set_code", decode.string)
    decode.success(TargetSetBody(set_code:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub fn encode_set_completion(
  rows: List(set_completion_ports.SetCompletionReadModel),
) -> String {
  json.array(rows, of: encode_set_completion_row)
  |> json.to_string
}

fn encode_set_completion_row(
  row: set_completion_ports.SetCompletionReadModel,
) -> json.Json {
  json.object([
    #("set_code", json.string(row.set_code)),
    #("owned", json.int(row.owned)),
    #("total", json.nullable(row.total, json.int)),
  ])
}

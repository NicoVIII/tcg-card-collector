import gleam/json

pub fn encode_ok(msg: String) -> String {
  json.object([#("ok", json.string(msg))])
  |> json.to_string
}

pub fn encode_error(msg: String) -> String {
  json.object([#("error", json.string(msg))])
  |> json.to_string
}

import gleam/erlang/charlist
import gleam/string

@external(erlang, "os", "cmd")
fn erl_cmd(command: charlist.Charlist) -> charlist.Charlist

@external(erlang, "os", "getenv")
fn erl_getenv(
  name: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist

pub fn cmd(command: String) -> String {
  erl_cmd(charlist.from_string(command))
  |> charlist.to_string
}

pub fn getenv_or(name: String, default: String) -> String {
  erl_getenv(charlist.from_string(name), charlist.from_string(default))
  |> charlist.to_string
}

pub fn getenv(name: String) -> Result(String, Nil) {
  let value = getenv_or(name, "")
  case string.trim(value) {
    "" -> Error(Nil)
    actual -> Ok(actual)
  }
}

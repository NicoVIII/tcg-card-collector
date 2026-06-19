import common/os_runtime
import gleam/string

const timeout_seconds = "540"

pub fn quote(value: String) -> String {
  "'" <> string.replace(value, "'", "'\"'\"'") <> "'"
}

pub fn run(script: String) -> Result(String, String) {
  let wrapped =
    "set +e; " <> script <> "; status=$?; printf '\n__EXIT__:%s' \"$status\""
  let command =
    "timeout --signal=TERM --kill-after=10 "
    <> timeout_seconds
    <> " sh -c "
    <> quote(wrapped)
  let output = os_runtime.cmd(command)
  case string.split(output, "__EXIT__:") {
    [body, status_raw] ->
      case string.trim(status_raw) {
        "0" -> Ok(string.trim(body))
        _ -> Error(string.trim(body))
      }
    _ -> Error(string.trim(output))
  }
}

pub fn simplify_error(output: String) -> String {
  let trimmed = string.trim(output)
  case trimmed == "" {
    True -> "unknown error"
    False -> trimmed
  }
}

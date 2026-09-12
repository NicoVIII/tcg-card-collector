import gleam/string
import shared/infrastructure/os_runtime

const timeout_seconds = "540"

pub fn quote(value: String) -> String {
  "'" <> string.replace(value, "'", "'\"'\"'") <> "'"
}

pub fn run(script: String) -> Result(String, String) {
  let wrapped =
    "set +e; " <> script <> "; status=$?; printf '\n__EXIT__:%s' \"$status\""
  let command =
    "timeout -s TERM -k 10 " <> timeout_seconds <> " sh -c " <> quote(wrapped)
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

/// Best-effort removal of a scratch file: nothing the caller could do differs
/// on failure, so the outcome is deliberately dropped.
pub fn remove_file(path: String) -> Nil {
  // nolint: discarded_result -- best-effort cleanup, see doc comment
  let _ = run("rm -f " <> quote(path))
  Nil
}

pub fn simplify_error(output: String) -> String {
  let trimmed = string.trim(output)
  case trimmed == "" {
    True -> "unknown error"
    False -> trimmed
  }
}

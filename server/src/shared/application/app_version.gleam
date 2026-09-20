import gleam/string

// Non-release builds get a "-dev+<short sha>" suffix so a `main` image can
// never be mistaken for the release it followed (issue #91).
const dev_commit_length = 7

pub type AppVersion {
  AppVersion(version: String)
}

pub fn compose(base: String, channel: String, commit: String) -> AppVersion {
  case channel {
    "release" -> AppVersion(base)
    _ -> AppVersion(base <> "-dev+" <> short_commit(commit))
  }
}

fn short_commit(commit: String) -> String {
  case string.trim(commit) {
    "" -> "local"
    trimmed -> string.slice(trimmed, at_index: 0, length: dev_commit_length)
  }
}

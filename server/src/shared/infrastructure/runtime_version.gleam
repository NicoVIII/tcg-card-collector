import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/list
import gleam/result
import gleam/string
import shared/application/app_version.{type AppVersion}
import shared/infrastructure/os_runtime

// Not exposed by gleam_erlang/gleam/erlang/application (only priv_directory
// is); every Gleam package is loaded as an OTP application, and its `gleam.
// toml` version is compiled straight into the resulting .app resource file
// as `vsn`, so reading it back is a supported use of a stable OTP API.
@external(erlang, "application", "get_key")
fn erl_get_key(app: atom.Atom, key: atom.Atom) -> decode.Dynamic

pub fn read() -> AppVersion {
  app_version.compose(
    read_gleam_toml_version(),
    os_runtime.getenv_or("TCG_APP_CHANNEL", "dev"),
    os_runtime.getenv_or("TCG_APP_COMMIT", ""),
  )
}

// `application:get_key/2` answers `{ok, Vsn} | undefined`, Vsn a charlist —
// decoded soundly rather than cast, since a boot-time failure here must
// degrade, never crash the server.
fn read_gleam_toml_version() -> String {
  erl_get_key(atom.create("tcg_card_collector"), atom.create("vsn"))
  |> decode.run(
    decode.at([1], decode.list(decode.int)) |> decode.map(codepoints_to_string),
  )
  |> result.unwrap("unknown")
}

fn codepoints_to_string(codes: List(Int)) -> String {
  codes
  |> list.filter_map(string.utf_codepoint)
  |> string.from_utf_codepoints
}

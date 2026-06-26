import gleam/crypto
import gleam/dict
import gleam/list
import gleam/string
import simplifile

pub opaque type T {
  T(dict.Dict(BitArray, String))
}

fn hash_source(source: String) -> BitArray {
  crypto.hash(crypto.Sha1, <<source:utf8>>)
}

pub fn build(dir: String) -> T {
  let assert Ok(files) = simplifile.get_files(in: dir)
  let prefix = dir <> "/"
  let map =
    files
    |> list.filter(string.ends_with(_, ".gleam"))
    |> list.filter(fn(path) { !string.contains(path, "/skirout/") })
    |> list.fold(dict.new(), fn(acc, path) {
      let assert Ok(source) = simplifile.read(from: path)
      let hash = hash_source(source)
      let module_path =
        path
        |> string.drop_start(string.length(prefix))
        |> string.drop_end(string.length(".gleam"))
      case dict.has_key(acc, hash) {
        True -> panic as { "Source map hash collision: " <> module_path }
        False -> dict.insert(acc, hash, module_path)
      }
    })
  T(map)
}

pub fn get(map: T, source: String) -> Result(String, Nil) {
  let T(inner) = map
  dict.get(inner, hash_source(source))
}

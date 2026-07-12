import gleam/dict
import gleam/option.{type Option, None, Some}
import inventory_planning/domain/set_index.{SetMeta}

fn index(entries: List(#(String, Option(String)))) -> set_index.SetIndex {
  entries
  |> dict.from_list
  |> dict.map_values(fn(_code, parent) {
    SetMeta(released_at: "", parent_set_code: parent)
  })
}

// A child set resolves to its parent as the family root.
pub fn child_resolves_to_parent_test() {
  let sets = index([#("tgrn", Some("grn")), #("grn", None)])
  assert set_index.family_root(sets, "tgrn") == "grn"
}

// A grandchild walks the parent chain transitively to the top.
pub fn grandchild_resolves_transitively_test() {
  let sets =
    index([#("ggg", Some("child")), #("child", Some("root")), #("root", None)])
  assert set_index.family_root(sets, "ggg") == "root"
}

// A set not in the index is its own family root.
pub fn unknown_set_is_own_root_test() {
  assert set_index.family_root(dict.new(), "xyz") == "xyz"
}

// A set with no parent is its own family root.
pub fn root_set_is_own_root_test() {
  let sets = index([#("grn", None)])
  assert set_index.family_root(sets, "grn") == "grn"
}

// A corrupt parent cycle (a↔b) terminates instead of looping forever, and does
// so deterministically (same input → same output).
pub fn parent_cycle_terminates_deterministically_test() {
  let sets = index([#("a", Some("b")), #("b", Some("a"))])
  let first = set_index.family_root(sets, "a")
  assert first == set_index.family_root(sets, "a")
}

// release_date reads the indexed date, and is "" for an unknown set.
pub fn release_date_reads_index_and_defaults_empty_test() {
  let sets =
    dict.from_list([
      #("grn", SetMeta(released_at: "2018-10-05", parent_set_code: None)),
    ])
  assert set_index.release_date(sets, "grn") == "2018-10-05"
  assert set_index.release_date(sets, "xyz") == ""
}

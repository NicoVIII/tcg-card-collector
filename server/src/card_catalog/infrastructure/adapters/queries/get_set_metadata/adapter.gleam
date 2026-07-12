import card_catalog/application/queries/get_set_metadata/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import shared/domain/release_date

pub fn new() -> ports.GetSetMetadataPort {
  fn(set_codes) {
    use rows <- result.try(catalog_dao.get_set_metadata(set_codes))
    rows
    |> list.try_map(fn(row) {
      let #(set_code, released_at_raw, parent_set_code) = row
      // '' means the source didn't date the set; anything else must parse —
      // the sync boundary only stores canonical strings, so a failure here is
      // corrupt stored data and propagates as a read error (ADR 0008).
      use released_at <- result.map(case string.trim(released_at_raw) {
        "" -> Ok(None)
        trimmed ->
          release_date.parse(trimmed)
          |> result.map(Some)
          |> result.replace_error(
            "corrupt catalog set "
            <> set_code
            <> ": invalid released_at: "
            <> released_at_raw,
          )
      })
      #(set_code, ports.SetMetadata(released_at:, parent_set_code:))
    })
    |> result.map(dict.from_list)
  }
}

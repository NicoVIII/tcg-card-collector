import card_catalog/application/queries/get_cards/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import shared/domain/color_identity
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date

pub fn new() -> ports.GetCatalogCardsPort {
  ports.GetCatalogCardsPort(get_cards: get_cards_adapter())
}

fn get_cards_adapter() -> fn(List(#(String, String))) ->
  Result(List(ports.CardReadModel), String) {
  fn(keys) {
    use rows <- result.try(catalog_dao.get_by_keys(keys))
    list.try_map(rows, to_read_model)
  }
}

// The sync boundary only stores canonical strings, so a parse failure here is
// corrupt stored data: propagate it as a read error rather than degrading the
// attribute (ADR 0008). A refresh rewrites the table, so recovery is cheap.
fn to_read_model(
  row: #(String, String, String, String, String, String, String, String, String),
) -> Result(ports.CardReadModel, String) {
  let #(
    set_code,
    collector_number,
    name,
    image_uri,
    rarity_raw,
    oracle_id_raw,
    color_identity_raw,
    type_line,
    released_at_raw,
  ) = row
  let corrupt = fn(field: String, value: String) {
    "corrupt catalog row "
    <> set_code
    <> "/"
    <> collector_number
    <> ": invalid "
    <> field
    <> ": "
    <> value
  }
  use rarity_value <- result.try(
    rarity.parse(rarity_raw)
    |> result.replace_error(corrupt("rarity", rarity_raw)),
  )
  use colors <- result.try(
    color_identity.parse(color_identity_raw)
    |> result.replace_error(corrupt("color_identity", color_identity_raw)),
  )
  use date <- result.map(
    parse_optional(released_at_raw, release_date.parse)
    |> result.replace_error(corrupt("released_at", released_at_raw)),
  )
  ports.CardReadModel(
    set_code:,
    collector_number:,
    name:,
    image_uri:,
    rarity: rarity_value,
    oracle_id: option.from_result(oracle_id.new(oracle_id_raw)),
    color_identity: colors,
    type_line:,
    released_at: date,
  )
}

fn parse_optional(
  raw: String,
  parse: fn(String) -> Result(a, Nil),
) -> Result(Option(a), Nil) {
  case string.trim(raw) {
    "" -> Ok(None)
    trimmed ->
      case parse(trimmed) {
        Ok(value) -> Ok(Some(value))
        Error(Nil) -> Error(Nil)
      }
  }
}

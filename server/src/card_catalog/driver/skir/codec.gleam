import card_catalog/application/queries/get_cards/ports as get_cards_ports
import card_catalog/application/queries/list_cards/ports as list_cards_ports
import card_catalog/application/queries/refresh_status/ports as refresh_status_ports
import card_catalog/driver/refresh_launcher.{
  RefreshAlreadyRunning, RefreshStarted,
}
import gleam/list
import gleam/option
import shared/domain/color_identity
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date
import shared/driver/search_filter
import shared/driver/skir/skirout/card_catalog/commands as card_catalog_commands
import shared/driver/skir/skirout/card_catalog/queries as card_catalog_queries

pub fn map_refresh_launch_result(
  outcome: refresh_launcher.RefreshLaunchOutcome,
) -> card_catalog_commands.RefreshCatalogResponse {
  case outcome {
    RefreshStarted -> card_catalog_commands.RefreshCatalogResponseStarted
    RefreshAlreadyRunning ->
      card_catalog_commands.RefreshCatalogResponseAlreadyRunning
  }
}

pub fn map_refresh_status_result(
  status: refresh_status_ports.RefreshStatusReadModel,
) -> card_catalog_queries.CatalogRefreshStatus {
  // arg order: error_message, last_probe_at, last_upstream_updated_at, status
  // (alphabetical per generated constructor)
  card_catalog_queries.catalog_refresh_status_new(
    status.error_message,
    status.last_probe_at,
    status.last_upstream_updated_at,
    status.status,
  )
}

pub fn to_key_pair(
  key: card_catalog_queries.CatalogCardKey,
) -> #(String, String) {
  #(key.set_code, key.collector_number)
}

pub fn to_catalog_card_filter(
  req: card_catalog_queries.ListCatalogCardsRequest,
) -> list_cards_ports.CatalogCardFilter {
  list_cards_ports.CatalogCardFilter(
    name: search_filter.parse_name(req.name),
    set_code: search_filter.parse_set_code(req.set_code),
  )
}

fn clamp_non_negative(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

// A limit of 0 means "no limit"; negative offsets and limits count as 0.
fn paginate_keys(
  keys: List(list_cards_ports.CatalogCardKeyReadModel),
  offset: Int,
  limit: Int,
) -> List(list_cards_ports.CatalogCardKeyReadModel) {
  let remaining = list.drop(keys, clamp_non_negative(offset))
  case clamp_non_negative(limit) {
    0 -> remaining
    normalized_limit -> list.take(remaining, normalized_limit)
  }
}

fn map_catalog_card_key(
  key: list_cards_ports.CatalogCardKeyReadModel,
) -> card_catalog_queries.CatalogCardKey {
  // arg order: collector_number, set_code (alphabetical per generated constructor)
  card_catalog_queries.catalog_card_key_new(key.collector_number, key.set_code)
}

pub fn map_catalog_card_key_page(
  all_keys: List(list_cards_ports.CatalogCardKeyReadModel),
  offset: Int,
  limit: Int,
) -> card_catalog_queries.CatalogCardKeyList {
  card_catalog_queries.catalog_card_key_list_new(
    list.map(paginate_keys(all_keys, offset, limit), map_catalog_card_key),
    limit,
    offset,
    list.length(all_keys),
  )
}

// The wire keeps the canonical string forms ('' for an absent value); strong
// types exist inland only (ADR 0008).
fn map_card_read_model(
  card: get_cards_ports.CardReadModel,
) -> card_catalog_queries.CatalogCard {
  // arg order is alphabetical per generated constructor:
  // collector_number, color_identity, image_uri, name, oracle_id, rarity,
  // released_at, set_code, type_line
  card_catalog_queries.catalog_card_new(
    card.collector_number,
    color_identity.letters(card.color_identity),
    card.image_uri,
    card.name,
    card.oracle_id |> option.map(oracle_id.to_string) |> option.unwrap(""),
    rarity.to_string(card.rarity),
    card.released_at
      |> option.map(release_date.to_string)
      |> option.unwrap(""),
    card.set_code,
    card.type_line,
  )
}

pub fn map_catalog_card_list(
  cards: List(get_cards_ports.CardReadModel),
) -> card_catalog_queries.CatalogCardList {
  card_catalog_queries.catalog_card_list_new(list.map(
    cards,
    map_card_read_model,
  ))
}

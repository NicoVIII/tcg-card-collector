import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/list_cards/ports as list_collection_cards_ports
import gleam/list
import shared/domain/card_key
import shared/driver/skir/skirout/collection/commands as collection_commands
import shared/driver/skir/skirout/collection/queries as collection_queries
import skir_client/service

pub fn map_import_collection_result(
  result: Result(Nil, import_collection_ports.ImportCollectionError),
) -> Result(collection_commands.ImportCollectionResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.ImportCollectionResponseAccepted)
    Error(import_collection_ports.InvalidRows) ->
      Ok(collection_commands.ImportCollectionResponseRejected)
    Error(import_collection_ports.PersistenceFailed(reason)) ->
      Error(service.ServiceError(service.E500xInternalServerError, reason))
  }
}

pub fn map_add_cards_result(
  result: Result(Nil, add_cards_ports.AddCardsError),
) -> Result(collection_commands.AddCardsResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.AddCardsResponseAdded)
    Error(add_cards_ports.InvalidRows) ->
      Ok(collection_commands.AddCardsResponseRejected)
    Error(add_cards_ports.PersistenceFailed(reason)) ->
      Error(service.ServiceError(service.E500xInternalServerError, reason))
  }
}

pub fn to_import_collection_row(
  row: collection_commands.ImportCollectionRow,
) -> import_collection_ports.ImportCollectionRow {
  import_collection_ports.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

pub fn to_add_cards_row(
  row: collection_commands.AddCardsRow,
) -> add_cards_ports.AddCardsRow {
  add_cards_ports.AddCardsRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

fn map_collection_card(
  card: list_collection_cards_ports.CollectionCardReadModel,
) -> collection_queries.CollectionCard {
  collection_queries.collection_card_new(
    card_key.collector_number_string(card.key),
    card.quantity,
    card_key.set_code_string(card.key),
  )
}

pub fn map_collection_card_page(
  page: list_collection_cards_ports.CollectionCardPage,
  offset: Int,
  limit: Int,
) -> collection_queries.CollectionCardList {
  collection_queries.collection_card_list_new(
    list.map(page.cards, map_collection_card),
    limit,
    offset,
    page.total,
  )
}

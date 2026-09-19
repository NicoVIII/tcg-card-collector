import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/commands/remove_cards/ports as remove_cards_ports
import collection/application/queries/list_cards/ports as list_collection_cards_ports
import collection/driver/error_presentation
import gleam/list
import shared/domain/card_key
import shared/driver/skir/helpers
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

pub fn map_remove_cards_result(
  result: Result(Nil, remove_cards_ports.RemoveCardsError),
) -> Result(collection_commands.RemoveCardsResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(collection_commands.RemoveCardsResponseDecremented)
    Error(remove_cards_ports.InvalidRows) ->
      Ok(collection_commands.RemoveCardsResponseRejected)
    Error(remove_cards_ports.PersistenceFailed(reason)) ->
      Error(helpers.service_error(error_presentation.remove_cards(reason)))
  }
}

pub fn to_import_collection_row(
  row: collection_commands.ImportCollectionRow,
) -> import_collection_ports.ImportCollectionRow {
  import_collection_ports.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: command_finish_to_string(row.finish),
    language: command_language_to_string(row.language),
    quantity: row.quantity,
  )
}

pub fn to_add_cards_row(
  row: collection_commands.AddCardsRow,
) -> add_cards_ports.AddCardsRow {
  add_cards_ports.AddCardsRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: command_finish_to_string(row.finish),
    language: command_language_to_string(row.language),
    quantity: row.quantity,
  )
}

pub fn to_remove_cards_row(
  row: collection_commands.RemoveCardsRow,
) -> remove_cards_ports.RemoveCardsRow {
  remove_cards_ports.RemoveCardsRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: command_finish_to_string(row.finish),
    language: command_language_to_string(row.language),
    quantity: row.quantity,
  )
}

// Every wire enum used at this boundary is validated downstream (copy_key's
// constructors): an unrecognized variant maps to an empty string, which fails
// validation and rejects the whole row rather than silently defaulting.
fn command_finish_to_string(value: collection_commands.Finish) -> String {
  case value {
    collection_commands.FinishNonfoil -> "nonfoil"
    collection_commands.FinishFoil -> "foil"
    collection_commands.FinishEtched -> "etched"
    collection_commands.FinishUnknown(_) -> ""
  }
}

fn command_language_to_string(value: collection_commands.Language) -> String {
  case value {
    collection_commands.LanguageEn -> "en"
    collection_commands.LanguageEs -> "es"
    collection_commands.LanguageFr -> "fr"
    collection_commands.LanguageDe -> "de"
    collection_commands.LanguageIt -> "it"
    collection_commands.LanguagePt -> "pt"
    collection_commands.LanguageJa -> "ja"
    collection_commands.LanguageKo -> "ko"
    collection_commands.LanguageRu -> "ru"
    collection_commands.LanguageZhs -> "zhs"
    collection_commands.LanguageZht -> "zht"
    collection_commands.LanguageHe -> "he"
    collection_commands.LanguageLa -> "la"
    collection_commands.LanguageGrc -> "grc"
    collection_commands.LanguageAr -> "ar"
    collection_commands.LanguageSa -> "sa"
    collection_commands.LanguagePh -> "ph"
    collection_commands.LanguageQya -> "qya"
    collection_commands.LanguageUnknown(_) -> ""
  }
}

fn query_finish_from_string(raw: String) -> collection_queries.Finish {
  case raw {
    "nonfoil" -> collection_queries.FinishNonfoil
    "foil" -> collection_queries.FinishFoil
    "etched" -> collection_queries.FinishEtched
    _ -> collection_queries.finish_unknown
  }
}

fn query_language_from_string(raw: String) -> collection_queries.Language {
  case raw {
    "en" -> collection_queries.LanguageEn
    "es" -> collection_queries.LanguageEs
    "fr" -> collection_queries.LanguageFr
    "de" -> collection_queries.LanguageDe
    "it" -> collection_queries.LanguageIt
    "pt" -> collection_queries.LanguagePt
    "ja" -> collection_queries.LanguageJa
    "ko" -> collection_queries.LanguageKo
    "ru" -> collection_queries.LanguageRu
    "zhs" -> collection_queries.LanguageZhs
    "zht" -> collection_queries.LanguageZht
    "he" -> collection_queries.LanguageHe
    "la" -> collection_queries.LanguageLa
    "grc" -> collection_queries.LanguageGrc
    "ar" -> collection_queries.LanguageAr
    "sa" -> collection_queries.LanguageSa
    "ph" -> collection_queries.LanguagePh
    "qya" -> collection_queries.LanguageQya
    _ -> collection_queries.language_unknown
  }
}

fn map_owned_copy(
  copy: list_collection_cards_ports.OwnedCopy,
) -> collection_queries.CollectionCopy {
  collection_queries.collection_copy_new(
    finish: query_finish_from_string(copy.finish),
    language: query_language_from_string(copy.language),
    quantity: copy.quantity,
  )
}

fn map_owned_printing(
  printing: list_collection_cards_ports.OwnedPrinting,
) -> collection_queries.CollectionCard {
  collection_queries.collection_card_new(
    collector_number: card_key.collector_number_string(printing.key),
    copies: list.map(printing.copies, map_owned_copy),
    set_code: card_key.set_code_string(printing.key),
  )
}

pub fn map_collection_card_page(
  page: list_collection_cards_ports.CollectionCardPage,
  offset: Int,
  limit: Int,
) -> collection_queries.CollectionCardList {
  collection_queries.collection_card_list_new(
    list.map(page.printings, map_owned_printing),
    limit,
    offset,
    page.total,
  )
}

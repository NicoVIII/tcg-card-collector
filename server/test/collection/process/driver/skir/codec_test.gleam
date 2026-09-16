import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/list_cards/ports as list_collection_cards_ports
import collection/driver/skir/codec as collection_skir_codec
import shared/domain/card_key
import shared/driver/skir/skirout/collection/commands as collection_commands
import shared/driver/skir/skirout/collection/queries as collection_queries
import skir_client/service

pub fn import_ok_maps_to_accepted_test() {
  assert collection_skir_codec.map_import_collection_result(Ok(Nil))
    == Ok(collection_commands.ImportCollectionResponseAccepted)
}

pub fn import_invalid_rows_maps_to_rejected_test() {
  assert collection_skir_codec.map_import_collection_result(Error(
      import_collection_ports.InvalidRows,
    ))
    == Ok(collection_commands.ImportCollectionResponseRejected)
}

pub fn import_persistence_failed_maps_to_service_error_test() {
  assert collection_skir_codec.map_import_collection_result(
      Error(import_collection_ports.PersistenceFailed("db unavailable")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "db unavailable",
    ))
}

pub fn add_cards_ok_maps_to_added_test() {
  assert collection_skir_codec.map_add_cards_result(Ok(Nil))
    == Ok(collection_commands.AddCardsResponseAdded)
}

pub fn add_cards_invalid_rows_maps_to_rejected_test() {
  assert collection_skir_codec.map_add_cards_result(Error(
      add_cards_ports.InvalidRows,
    ))
    == Ok(collection_commands.AddCardsResponseRejected)
}

pub fn add_cards_persistence_failed_maps_to_service_error_test() {
  assert collection_skir_codec.map_add_cards_result(
      Error(add_cards_ports.PersistenceFailed("db unavailable")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "db unavailable",
    ))
}

pub fn to_import_collection_row_maps_finish_and_language_test() {
  let row =
    collection_commands.import_collection_row_new(
      collector_number: "161",
      finish: collection_commands.FinishFoil,
      language: collection_commands.LanguageDe,
      quantity: 2,
      set_code: "lea",
    )

  assert collection_skir_codec.to_import_collection_row(row)
    == import_collection_ports.ImportCollectionRow(
      set_code: "lea",
      collector_number: "161",
      finish: "foil",
      language: "de",
      quantity: 2,
    )
}

// An unrecognized wire variant maps to an empty string, which the domain
// constructors downstream reject rather than silently defaulting.
pub fn to_import_collection_row_maps_unknown_finish_to_empty_string_test() {
  let row =
    collection_commands.import_collection_row_new(
      collector_number: "161",
      finish: collection_commands.finish_unknown,
      language: collection_commands.LanguageEn,
      quantity: 1,
      set_code: "lea",
    )

  assert collection_skir_codec.to_import_collection_row(row).finish == ""
}

pub fn to_add_cards_row_maps_finish_and_language_test() {
  let row =
    collection_commands.add_cards_row_new(
      collector_number: "161",
      finish: collection_commands.FinishEtched,
      language: collection_commands.LanguageJa,
      quantity: 1,
      set_code: "lea",
    )

  assert collection_skir_codec.to_add_cards_row(row)
    == add_cards_ports.AddCardsRow(
      set_code: "lea",
      collector_number: "161",
      finish: "etched",
      language: "ja",
      quantity: 1,
    )
}

pub fn map_collection_card_page_maps_printings_and_echoes_paging_test() {
  let assert Ok(key) = card_key.new(set_code: "lea", collector_number: "161")
  let page =
    list_collection_cards_ports.CollectionCardPage(
      printings: [
        list_collection_cards_ports.OwnedPrinting(key:, copies: [
          list_collection_cards_ports.OwnedCopy(
            finish: "nonfoil",
            language: "en",
            quantity: 3,
          ),
          list_collection_cards_ports.OwnedCopy(
            finish: "foil",
            language: "de",
            quantity: 1,
          ),
        ]),
      ],
      total: 30,
    )

  let mapped = collection_skir_codec.map_collection_card_page(page, 10, 25)

  assert mapped.offset == 10
  assert mapped.limit == 25
  assert mapped.total == 30
  let assert [card] = mapped.data
  assert card.set_code == "lea"
  assert card.collector_number == "161"
  assert card.copies
    == [
      collection_queries.collection_copy_new(
        finish: collection_queries.FinishNonfoil,
        language: collection_queries.LanguageEn,
        quantity: 3,
      ),
      collection_queries.collection_copy_new(
        finish: collection_queries.FinishFoil,
        language: collection_queries.LanguageDe,
        quantity: 1,
      ),
    ]
}

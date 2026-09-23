import collection/application/queries/list_cards/ports as list_cards_ports
import collection/driver/http/json_codec as collection_codec
import shared/domain/card_key

pub fn decode_import_collection_body_with_rows_test() {
  let json_string =
    "{"
    <> "\"rows\": ["
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"finish\": \"nonfoil\", \"language\": \"en\", \"quantity\": 2},"
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"2\", \"finish\": \"foil\", \"language\": \"de\", \"quantity\": 1}"
    <> "]"
    <> "}"

  let assert Ok(body) =
    collection_codec.decode_import_collection_body(json_string)

  assert body.rows
    == [
      collection_codec.ImportCollectionRow(
        set_code: "mh3",
        collector_number: "1",
        finish: "nonfoil",
        language: "en",
        quantity: 2,
      ),
      collection_codec.ImportCollectionRow(
        set_code: "mh3",
        collector_number: "2",
        finish: "foil",
        language: "de",
        quantity: 1,
      ),
    ]
}

pub fn decode_import_collection_body_without_rows_defaults_to_empty_test() {
  let assert Ok(body) = collection_codec.decode_import_collection_body("{}")

  assert body.rows == []
}

pub fn decode_import_collection_body_invalid_json_test() {
  assert collection_codec.decode_import_collection_body("not json")
    == Error("invalid request body")
}

pub fn decode_add_cards_body_with_rows_test() {
  let json_string =
    "{"
    <> "\"rows\": ["
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"finish\": \"nonfoil\", \"language\": \"en\", \"quantity\": 2}"
    <> "]"
    <> "}"

  let assert Ok(body) = collection_codec.decode_add_cards_body(json_string)

  assert body.rows
    == [
      collection_codec.AddCardsRow(
        set_code: "mh3",
        collector_number: "1",
        finish: "nonfoil",
        language: "en",
        quantity: 2,
      ),
    ]
}

pub fn decode_add_cards_body_without_rows_defaults_to_empty_test() {
  let assert Ok(body) = collection_codec.decode_add_cards_body("{}")

  assert body.rows == []
}

pub fn decode_add_cards_body_invalid_json_test() {
  assert collection_codec.decode_add_cards_body("not json")
    == Error("invalid request body")
}

pub fn decode_remove_cards_body_with_rows_test() {
  let json_string =
    "{"
    <> "\"rows\": ["
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"finish\": \"nonfoil\", \"language\": \"en\", \"quantity\": 2}"
    <> "]"
    <> "}"

  let assert Ok(body) = collection_codec.decode_remove_cards_body(json_string)

  assert body.rows
    == [
      collection_codec.RemoveCardsRow(
        set_code: "mh3",
        collector_number: "1",
        finish: "nonfoil",
        language: "en",
        quantity: 2,
      ),
    ]
}

pub fn decode_remove_cards_body_without_rows_defaults_to_empty_test() {
  let assert Ok(body) = collection_codec.decode_remove_cards_body("{}")

  assert body.rows == []
}

pub fn decode_remove_cards_body_invalid_json_test() {
  assert collection_codec.decode_remove_cards_body("not json")
    == Error("invalid request body")
}

pub fn encode_collection_card_page_matches_the_skir_doors_shape_test() {
  let assert Ok(key) = card_key.new(set_code: "lea", collector_number: "1")
  let page =
    list_cards_ports.CollectionCardPage(
      printings: [
        list_cards_ports.OwnedPrinting(key:, copies: [
          list_cards_ports.OwnedCopy(
            finish: "nonfoil",
            language: "en",
            quantity: 2,
          ),
        ]),
      ],
      total: 5,
    )

  let json_string = collection_codec.encode_collection_card_page(page, 0, 25)

  assert json_string
    == "{\"data\":[{\"set_code\":\"lea\",\"collector_number\":\"1\",\"copies\":[{\"finish\":\"nonfoil\",\"language\":\"en\",\"quantity\":2}]}],\"total\":5,\"offset\":0,\"limit\":25}"
}

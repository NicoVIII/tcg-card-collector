import collection/driver/http/json_codec as collection_codec

pub fn decode_import_collection_body_with_rows_test() {
  let json_string =
    "{"
    <> "\"rows\": ["
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"quantity\": 2},"
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"2\", \"quantity\": 1}"
    <> "]"
    <> "}"

  let assert Ok(body) =
    collection_codec.decode_import_collection_body(json_string)

  assert body.rows
    == [
      collection_codec.ImportCollectionRow(
        set_code: "mh3",
        collector_number: "1",
        quantity: 2,
      ),
      collection_codec.ImportCollectionRow(
        set_code: "mh3",
        collector_number: "2",
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
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"quantity\": 2}"
    <> "]"
    <> "}"

  let assert Ok(body) = collection_codec.decode_add_cards_body(json_string)

  assert body.rows
    == [
      collection_codec.AddCardsRow(
        set_code: "mh3",
        collector_number: "1",
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

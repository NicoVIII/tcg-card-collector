import collection/application/queries/latest_status/ports as latest_status_ports
import collection/domain/import_status
import collection/driver/http/json_codec as collection_codec

pub fn decode_import_collection_body_with_rows_test() {
  let json_string =
    "{"
    <> "\"import_run_id\": \"run-1\","
    <> "\"source_name\": \"test.csv\","
    <> "\"row_count\": 2,"
    <> "\"rows\": ["
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"quantity\": 2},"
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"2\", \"quantity\": 1}"
    <> "]"
    <> "}"

  let assert Ok(body) =
    collection_codec.decode_import_collection_body(json_string)

  assert body.import_run_id == "run-1"
  assert body.source_name == "test.csv"
  assert body.row_count == 2
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
  let json_string =
    "{"
    <> "\"import_run_id\": \"run-1\","
    <> "\"source_name\": \"test.csv\","
    <> "\"row_count\": 0"
    <> "}"

  let assert Ok(body) =
    collection_codec.decode_import_collection_body(json_string)

  assert body.rows == []
}

pub fn decode_import_collection_body_invalid_json_test() {
  assert collection_codec.decode_import_collection_body("not json")
    == Error("invalid request body")
}

pub fn decode_add_cards_body_with_rows_test() {
  let json_string =
    "{"
    <> "\"add_run_id\": \"add-1\","
    <> "\"rows\": ["
    <> "  {\"set_code\": \"mh3\", \"collector_number\": \"1\", \"quantity\": 2}"
    <> "]"
    <> "}"

  let assert Ok(body) = collection_codec.decode_add_cards_body(json_string)

  assert body.add_run_id == "add-1"
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
  let assert Ok(body) =
    collection_codec.decode_add_cards_body("{\"add_run_id\": \"add-1\"}")

  assert body.rows == []
}

pub fn decode_add_cards_body_invalid_json_test() {
  assert collection_codec.decode_add_cards_body("not json")
    == Error("invalid request body")
}

pub fn encode_import_status_found_test() {
  let run =
    latest_status_ports.ImportRunReadModel(
      id: "run-1",
      source_name: "test.csv",
      status: import_status.Succeeded,
      row_count: 3,
    )

  assert collection_codec.encode_import_status_found(run)
    == "{\"kind\":\"found\",\"run\":{\"id\":\"run-1\",\"source_name\":\"test.csv\",\"status\":\"succeeded\",\"row_count\":3}}"
}

pub fn encode_import_status_not_found_test() {
  assert collection_codec.encode_import_status_not_found()
    == "{\"kind\":\"not_found\"}"
}

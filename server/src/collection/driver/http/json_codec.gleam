import gleam/dynamic/decode
import gleam/json
import gleam/result

pub type ImportCollectionRow {
  ImportCollectionRow(set_code: String, collector_number: String, quantity: Int)
}

pub type ImportCollectionBody {
  ImportCollectionBody(rows: List(ImportCollectionRow))
}

fn import_collection_row_decoder() {
  use set_code <- decode.field("set_code", decode.string)
  use collector_number <- decode.field("collector_number", decode.string)
  use quantity <- decode.field("quantity", decode.int)
  decode.success(ImportCollectionRow(set_code:, collector_number:, quantity:))
}

pub fn decode_import_collection_body(
  json_string: String,
) -> Result(ImportCollectionBody, String) {
  let decoder = {
    // Absent rows decode to an empty batch, which the handler rejects —
    // mirrors the skir door, where an omitted list arrives empty.
    use rows <- decode.optional_field(
      "rows",
      [],
      decode.list(import_collection_row_decoder()),
    )
    decode.success(ImportCollectionBody(rows:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub type AddCardsRow {
  AddCardsRow(set_code: String, collector_number: String, quantity: Int)
}

pub type AddCardsBody {
  AddCardsBody(rows: List(AddCardsRow))
}

fn add_cards_row_decoder() {
  use set_code <- decode.field("set_code", decode.string)
  use collector_number <- decode.field("collector_number", decode.string)
  use quantity <- decode.field("quantity", decode.int)
  decode.success(AddCardsRow(set_code:, collector_number:, quantity:))
}

pub fn decode_add_cards_body(
  json_string: String,
) -> Result(AddCardsBody, String) {
  let decoder = {
    use rows <- decode.optional_field(
      "rows",
      [],
      decode.list(add_cards_row_decoder()),
    )
    decode.success(AddCardsBody(rows:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

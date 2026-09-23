import collection/application/queries/list_cards/ports as list_cards_ports
import gleam/dynamic/decode
import gleam/json
import gleam/result
import shared/domain/card_key

pub type ImportCollectionRow {
  ImportCollectionRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

pub type ImportCollectionBody {
  ImportCollectionBody(rows: List(ImportCollectionRow))
}

fn import_collection_row_decoder() -> decode.Decoder(ImportCollectionRow) {
  use set_code <- decode.field("set_code", decode.string)
  use collector_number <- decode.field("collector_number", decode.string)
  use finish <- decode.field("finish", decode.string)
  use language <- decode.field("language", decode.string)
  use quantity <- decode.field("quantity", decode.int)
  decode.success(ImportCollectionRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  ))
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
  AddCardsRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

pub type AddCardsBody {
  AddCardsBody(rows: List(AddCardsRow))
}

fn add_cards_row_decoder() -> decode.Decoder(AddCardsRow) {
  use set_code <- decode.field("set_code", decode.string)
  use collector_number <- decode.field("collector_number", decode.string)
  use finish <- decode.field("finish", decode.string)
  use language <- decode.field("language", decode.string)
  use quantity <- decode.field("quantity", decode.int)
  decode.success(AddCardsRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  ))
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

pub type RemoveCardsRow {
  RemoveCardsRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

pub type RemoveCardsBody {
  RemoveCardsBody(rows: List(RemoveCardsRow))
}

fn remove_cards_row_decoder() -> decode.Decoder(RemoveCardsRow) {
  use set_code <- decode.field("set_code", decode.string)
  use collector_number <- decode.field("collector_number", decode.string)
  use finish <- decode.field("finish", decode.string)
  use language <- decode.field("language", decode.string)
  use quantity <- decode.field("quantity", decode.int)
  decode.success(RemoveCardsRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  ))
}

pub fn decode_remove_cards_body(
  json_string: String,
) -> Result(RemoveCardsBody, String) {
  let decoder = {
    use rows <- decode.optional_field(
      "rows",
      [],
      decode.list(remove_cards_row_decoder()),
    )
    decode.success(RemoveCardsBody(rows:))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub fn encode_collection_card_page(
  page: list_cards_ports.CollectionCardPage,
  offset: Int,
  limit: Int,
) -> String {
  json.object([
    #("data", json.array(page.printings, of: encode_owned_printing)),
    #("total", json.int(page.total)),
    #("offset", json.int(offset)),
    #("limit", json.int(limit)),
  ])
  |> json.to_string
}

fn encode_owned_printing(
  printing: list_cards_ports.OwnedPrinting,
) -> json.Json {
  json.object([
    #("set_code", json.string(card_key.set_code_string(printing.key))),
    #(
      "collector_number",
      json.string(card_key.collector_number_string(printing.key)),
    ),
    #("copies", json.array(printing.copies, of: encode_owned_copy)),
  ])
}

fn encode_owned_copy(copy: list_cards_ports.OwnedCopy) -> json.Json {
  json.object([
    #("finish", json.string(copy.finish)),
    #("language", json.string(copy.language)),
    #("quantity", json.int(copy.quantity)),
  ])
}

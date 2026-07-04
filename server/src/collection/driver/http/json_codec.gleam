import collection/application/queries/latest_status/ports as import_ports
import collection/domain/import_status
import gleam/dynamic/decode
import gleam/json
import gleam/result

pub type ImportCollectionRow {
  ImportCollectionRow(set_code: String, collector_number: String, quantity: Int)
}

pub type ImportCollectionBody {
  ImportCollectionBody(
    import_run_id: String,
    source_name: String,
    row_count: Int,
    mode: String,
    rows: List(ImportCollectionRow),
  )
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
    use import_run_id <- decode.field("import_run_id", decode.string)
    use source_name <- decode.field("source_name", decode.string)
    use row_count <- decode.field("row_count", decode.int)
    use mode <- decode.optional_field("mode", "full", decode.string)
    use rows <- decode.optional_field(
      "rows",
      [],
      decode.list(import_collection_row_decoder()),
    )
    decode.success(ImportCollectionBody(
      import_run_id:,
      source_name:,
      row_count:,
      mode:,
      rows:,
    ))
  }

  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "invalid request body" })
}

pub fn encode_import_status_found(
  run: import_ports.ImportRunReadModel,
) -> String {
  json.object([
    #("kind", json.string("found")),
    #("run", encode_import_run(run)),
  ])
  |> json.to_string
}

pub fn encode_import_status_not_found() -> String {
  json.object([#("kind", json.string("not_found"))])
  |> json.to_string
}

fn encode_import_run(run: import_ports.ImportRunReadModel) -> json.Json {
  json.object([
    #("id", json.string(run.id)),
    #("source_name", json.string(run.source_name)),
    #("status", json.string(import_status.to_string(run.status))),
    #("row_count", json.int(run.row_count)),
  ])
}

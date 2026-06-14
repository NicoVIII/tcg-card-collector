import collection/application/queries/latest_status/ports as import_ports
import collection/domain/import_status
import gleam/dynamic/decode
import gleam/json
import gleam/result

pub type ImportCollectionBody {
  ImportCollectionBody(
    import_run_id: String,
    source_name: String,
    source_checksum: String,
    row_count: Int,
  )
}

pub fn decode_import_collection_body(
  json_string: String,
) -> Result(ImportCollectionBody, String) {
  let decoder = {
    use import_run_id <- decode.field("import_run_id", decode.string)
    use source_name <- decode.field("source_name", decode.string)
    use source_checksum <- decode.field("source_checksum", decode.string)
    use row_count <- decode.field("row_count", decode.int)
    decode.success(ImportCollectionBody(
      import_run_id:,
      source_name:,
      source_checksum:,
      row_count:,
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

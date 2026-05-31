import application/collection_import/ports
import gleam/option.{type Option, None, Some}

@external(erlang, "collection_import_store", "save")
fn save_to_store(
  id: String,
  source_name: String,
  status: String,
  row_count: Int,
) -> Nil

@external(erlang, "collection_import_store", "latest")
fn latest_from_store() -> Option(#(String, String, String, Int))

@external(erlang, "collection_import_store", "clear")
fn clear_store() -> Nil

pub fn new() -> ports.CollectionImportRepository {
  ports.CollectionImportRepository(
    save_import_run: fn(run) {
      let ports.ImportRunWriteModel(
        id: id,
        source_name: source_name,
        status: status,
        row_count: row_count,
      ) = run

      save_to_store(id, source_name, status, row_count)
    },
    latest_import_run: fn() {
      case latest_from_store() {
        None -> None
        Some(#(id, source_name, status, row_count)) ->
          Some(ports.ImportRunReadModel(
            id: id,
            source_name: source_name,
            status: status,
            row_count: row_count,
          ))
      }
    },
  )
}

pub fn reset_for_tests() -> Nil {
  clear_store()
}

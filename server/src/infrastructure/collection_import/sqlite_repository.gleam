import application/collection_import/ports
import gleam/option.{None}

pub fn new() -> ports.CollectionImportRepository {
  ports.CollectionImportRepository(
    save_import_run: fn(_run) { Nil },
    latest_import_run: fn() { None },
  )
}

import application/commands/database/refresh/ports
import infrastructure/stores/database/database_store

pub fn new() -> ports.RefreshDatabasePort {
  ports.RefreshDatabasePort(execute: fn() {
    case database_store.refresh() {
      Ok(_) -> Ok(Nil)
      Error(message) -> Error(ports.RefreshDatabaseError(message: message))
    }
  })
}

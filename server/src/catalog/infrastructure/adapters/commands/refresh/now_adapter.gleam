import catalog/application/commands/refresh/ports
import catalog/infrastructure/stores/catalog_store

pub fn get_now() -> ports.NowPort {
  catalog_store.now_timestamp
}

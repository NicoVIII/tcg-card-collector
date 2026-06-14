import catalog/application/commands/refresh/ports
import gleam/time/timestamp.{type Timestamp}

fn get_now() -> Timestamp {
  timestamp.system_time()
}

pub fn create() -> ports.NowPort {
  get_now
}

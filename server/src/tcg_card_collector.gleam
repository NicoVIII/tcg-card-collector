import composition
import driver/http/app_server

pub fn main() -> Nil {
  composition.log_boot_message()
  let deps = composition.dependencies()
  app_server.start(deps)
}

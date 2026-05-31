import composition
import gleam/io

pub fn main() -> Nil {
  composition.log_boot_message()
  let _dependencies = composition.dependencies()
  io.println("tcg-card-collector backend scaffold")
}

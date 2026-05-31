pub type Layer {
  Domain
  Application
  Infrastructure
  Driver
  Common
  Composition
  Root
}

pub fn allows(source: Layer, target: Layer) -> Bool {
  case source {
    Domain -> target == Domain || target == Common
    Application -> target == Application || target == Domain || target == Common
    Infrastructure ->
      target == Infrastructure || target == Application || target == Domain || target == Common
    Driver -> target == Driver || target == Application || target == Domain || target == Common
    Common -> target == Common
    Composition -> True
    Root -> True
  }
}

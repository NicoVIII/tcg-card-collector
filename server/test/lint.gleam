import gleam/string
import glinter
import glinter_arch/bounded_context
import glinter_arch/cqrs
import glinter_arch/depends_only_on
import glinter_arch/hexagonal.{Application, Domain, Driver, Infrastructure}
import glinter_arch/source_map

type BoundedContext {
  Catalog
  Collection
  InventoryPlanning
  Insights
}

type DriverType {
  Http
  Gleam
  Skir
}

type DriverCategory {
  Common
  Driving(DriverType)
}

type Layer =
  hexagonal.Layer(cqrs.Application, DriverCategory)

type External {
  GleamLibs
  MistLib
  Simplifile
  SkirLib
  Sqlight
}

type Category =
  bounded_context.Category(BoundedContext, Layer, External)

fn categorize_driver(tail: List(String)) -> DriverCategory {
  case tail {
    ["gleam", ..] -> Driving(Gleam)
    ["http", ..] -> Driving(Http)
    ["skir", ..] -> Driving(Skir)
    _ -> Common
  }
}

fn categorize(path: String) -> Category {
  case string.split(path, "/") {
    ["catalog", ..tail] ->
      bounded_context.Bc(
        Catalog,
        hexagonal.categorize_layer(
          cqrs.categorize_application,
          categorize_driver,
          tail,
        ),
      )
    ["collection", ..tail] ->
      bounded_context.Bc(
        Collection,
        hexagonal.categorize_layer(
          cqrs.categorize_application,
          categorize_driver,
          tail,
        ),
      )
    ["inventory_planning", ..tail] ->
      bounded_context.Bc(
        InventoryPlanning,
        hexagonal.categorize_layer(
          cqrs.categorize_application,
          categorize_driver,
          tail,
        ),
      )
    ["insights", ..tail] ->
      bounded_context.Bc(
        Insights,
        hexagonal.categorize_layer(
          cqrs.categorize_application,
          categorize_driver,
          tail,
        ),
      )
    ["shared", ..tail] ->
      bounded_context.Shared(hexagonal.categorize_layer(
        cqrs.categorize_application,
        categorize_driver,
        tail,
      ))
    ["bootstrap", ..] -> bounded_context.Bootstrap
    ["tcg_card_collector"] -> bounded_context.Bootstrap
    ["gleam", ..] -> bounded_context.External(GleamLibs)
    ["mist", ..] -> bounded_context.External(MistLib)
    ["skir_client", ..] -> bounded_context.External(SkirLib)
    ["simplifile", ..] -> bounded_context.External(Simplifile)
    ["sqlight", ..] -> bounded_context.External(Sqlight)
    x -> panic as { "Unknown path: " <> string.join(x, "/") }
  }
}

fn is_driver_allowed(from: DriverCategory, to: DriverCategory) -> Bool {
  to == Common || from == to
}

fn allowed_externals(layer: Layer) -> List(External) {
  case layer {
    Domain -> []
    Application(_) -> []
    Infrastructure -> [Simplifile, Sqlight]
    Driver(Common) -> []
    Driver(Driving(Http)) -> [MistLib]
    Driver(Driving(Gleam)) -> []
    Driver(Driving(Skir)) -> [SkirLib]
  }
}

fn describe_driver(driver: DriverCategory) -> String {
  case driver {
    Common -> "Common"
    Driving(Http) -> "Http"
    Driving(Gleam) -> "Gleam"
    Driving(Skir) -> "Skir"
  }
}

fn describe_bc(bc: BoundedContext, layer: Layer) -> String {
  let bc_str = case bc {
    Catalog -> "Catalog"
    Collection -> "Collection"
    InventoryPlanning -> "InventoryPlanning"
    Insights -> "Insights"
  }
  "BoundedContext("
  <> bc_str
  <> ", "
  <> hexagonal.describe_layer(cqrs.describe_application, describe_driver, layer)
  <> ")"
}

fn describe_external(ext: External) -> String {
  case ext {
    GleamLibs -> "GleamLibs"
    MistLib -> "MistLib"
    SkirLib -> "SkirLib"
    Simplifile -> "Simplifile"
    Sqlight -> "Sqlight"
  }
}

pub fn main() {
  let sm = source_map.build_source_map("./src")
  let describe_layer_fn = hexagonal.describe_layer(
    cqrs.describe_application,
    describe_driver,
    _,
  )
  let hex_config =
    bounded_context.Config(
      is_layer_allowed: fn(from, to) {
        hexagonal.is_layer_allowed(
          cqrs.is_application_allowed,
          cqrs.application_sees_domain,
          is_driver_allowed,
          from,
          to,
        )
      },
      allowed_externals: allowed_externals,
      is_universally_allowed_ext: fn(ext) { ext == GleamLibs },
      is_cross_bc_link: fn(from_layer, to_layer) {
        case from_layer, to_layer {
          Infrastructure, Driver(Driving(Gleam)) -> True
          _, _ -> False
        }
      },
      // Documented with a diagram in docs/dev/bounded-context-dependencies.md
      // — update it when this list changes.
      allowed_cross_bc: [
        #(InventoryPlanning, Catalog),
        #(InventoryPlanning, Collection),
        #(Insights, Catalog),
        #(Insights, Collection),
      ],
    )
  let config =
    depends_only_on.Config(
      categorize: categorize,
      is_allowed: fn(from, to) {
        bounded_context.is_allowed(hex_config, from, to)
      },
      describe: bounded_context.describe(
        describe_bc,
        describe_layer_fn,
        describe_external,
        _,
      ),
    )
  glinter.run(extra_rules: [depends_only_on.rule(config, sm)])
}

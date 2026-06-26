import gleam/list
import gleam/string
import glinter
import glinter_arch/depends_only_on
import glinter_arch/source_map

type BoundedContext {
  Catalog
  Collection
  InventoryPlanning
}

type Context {
  Bc(BoundedContext)
  Shared
  Bootstrap
  External
}

type Layer {
  Domain
  Application
  Infrastructure
  Driver
  GleamDriver
}

fn categorize(path: String) -> #(Context, Layer) {
  case string.split(path, "/") {
    ["catalog", "domain", ..] -> #(Bc(Catalog), Domain)
    ["catalog", "application", ..] -> #(Bc(Catalog), Application)
    ["catalog", "infrastructure", ..] -> #(Bc(Catalog), Infrastructure)
    ["catalog", "driver", "gleam", ..] -> #(Bc(Catalog), GleamDriver)
    ["catalog", "driver", ..] -> #(Bc(Catalog), Driver)
    ["collection", "domain", ..] -> #(Bc(Collection), Domain)
    ["collection", "application", ..] -> #(Bc(Collection), Application)
    ["collection", "infrastructure", ..] -> #(Bc(Collection), Infrastructure)
    ["collection", "driver", "gleam", ..] -> #(Bc(Collection), GleamDriver)
    ["collection", "driver", ..] -> #(Bc(Collection), Driver)
    ["inventory_planning", "domain", ..] -> #(Bc(InventoryPlanning), Domain)
    ["inventory_planning", "application", ..] -> #(
      Bc(InventoryPlanning),
      Application,
    )
    ["inventory_planning", "infrastructure", ..] -> #(
      Bc(InventoryPlanning),
      Infrastructure,
    )
    ["inventory_planning", "driver", "gleam", ..] -> #(
      Bc(InventoryPlanning),
      GleamDriver,
    )
    ["inventory_planning", "driver", ..] -> #(Bc(InventoryPlanning), Driver)
    ["shared", "domain", ..] -> #(Shared, Domain)
    ["shared", "application", ..] -> #(Shared, Application)
    ["shared", "infrastructure", ..] -> #(Shared, Infrastructure)
    ["bootstrap", ..] -> #(Bootstrap, Driver)
    _ -> #(External, Domain)
  }
}

fn allowed_layers(layer: Layer) -> List(Layer) {
  case layer {
    Domain -> [Domain]
    Application -> [Domain, Application]
    Infrastructure -> [Domain, Application, Infrastructure]
    Driver -> [Domain, Application, Driver]
    GleamDriver -> [Domain, Application, Infrastructure, GleamDriver]
  }
}

fn is_allowed(
  allowed_cross_bc: List(#(BoundedContext, BoundedContext)),
  from: #(Context, Layer),
  to: #(Context, Layer),
) -> Bool {
  let #(from_ctx, from_layer) = from
  let #(to_ctx, to_layer) = to
  case from_ctx {
    Bootstrap | External -> True
    _ ->
      case to_ctx {
        External -> True
        Bootstrap -> from_layer == Driver
        _ ->
          case from_ctx, to_ctx {
            Bc(x), Bc(y) ->
              case x == y {
                True -> list.contains(allowed_layers(from_layer), to_layer)
                False ->
                  list.contains(allowed_cross_bc, #(x, y))
                  && from_layer == Infrastructure
                  && to_layer == GleamDriver
              }
            Bc(_), Shared -> list.contains(allowed_layers(from_layer), to_layer)
            Shared, Shared ->
              list.contains(allowed_layers(from_layer), to_layer)
            Shared, Bc(_) -> False
            _, _ -> False
          }
      }
  }
}

fn describe(cat: #(Context, Layer)) -> String {
  let #(ctx, layer) = cat
  let ctx_str = case ctx {
    Bc(Catalog) -> "catalog"
    Bc(Collection) -> "collection"
    Bc(InventoryPlanning) -> "inventory_planning"
    Shared -> "shared"
    Bootstrap -> "bootstrap"
    External -> "external"
  }
  let layer_str = case layer {
    Domain -> "domain"
    Application -> "application"
    Infrastructure -> "infrastructure"
    Driver -> "driver"
    GleamDriver -> "driver/gleam"
  }
  ctx_str <> "/" <> layer_str
}

pub fn main() {
  let sm = source_map.build_source_map("./src")
  let allowed_cross_bc = [
    #(InventoryPlanning, Catalog),
    #(InventoryPlanning, Collection),
  ]
  let config =
    depends_only_on.Config(
      categorize: categorize,
      is_allowed: fn(from, to) { is_allowed(allowed_cross_bc, from, to) },
      describe: describe,
    )
  glinter.run(extra_rules: [depends_only_on.rule(config, sm)])
}

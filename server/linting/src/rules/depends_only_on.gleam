import glinter/rule
import gleam/list
import gleam/string
import source_map

pub type BoundedContext {
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

pub type Config {
  Config(allowed_cross_bc: List(#(BoundedContext, BoundedContext)))
}

fn category(path: String) -> #(Context, Layer) {
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
    ["inventory_planning", "application", ..] -> #(Bc(InventoryPlanning), Application)
    ["inventory_planning", "infrastructure", ..] -> #(Bc(InventoryPlanning), Infrastructure)
    ["inventory_planning", "driver", "gleam", ..] -> #(Bc(InventoryPlanning), GleamDriver)
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
  config: Config,
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
                  list.contains(config.allowed_cross_bc, #(x, y))
                  && from_layer == Infrastructure
                  && to_layer == GleamDriver
              }
            Bc(_), Shared -> list.contains(allowed_layers(from_layer), to_layer)
            Shared, Shared -> list.contains(allowed_layers(from_layer), to_layer)
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

pub fn rule(sm: source_map.T, config: Config) -> rule.Rule {
  rule.module_rule_from_fn(
    name: "depends_only_on",
    default_severity: rule.Error,
    run: fn(module, source) {
      case source_map.get(sm, source) {
        Error(Nil) -> []
        Ok(module_path) -> {
          let from = category(module_path)
          module.imports
          |> list.flat_map(fn(import_def) {
            let to = category(import_def.definition.module)
            case is_allowed(config, from, to) {
              True -> []
              False -> [
                rule.error(
                  message: "Forbidden import",
                  details: "from "
                    <> describe(from)
                    <> " to "
                    <> describe(to),
                  location: import_def.definition.location,
                ),
              ]
            }
          })
        }
      }
    },
  )
}

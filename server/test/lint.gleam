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

type DriverType {
  Http
  Gleam
  Skir
}

type DriverCategory {
  Common
  Driving(DriverType)
}

type Layer {
  Domain
  Application
  Infrastructure
  Driver(DriverCategory)
}

type External {
  GleamLibs
  MistLib
  Simplifile
  SkirLib
}

type Category {
  Bc(BoundedContext, Layer)
  Shared(Layer)
  Bootstrap
  External(External)
}

fn categorize_layer(path_parts: List(String)) -> Layer {
  case path_parts {
    ["domain", ..] -> Domain
    ["application", ..] -> Application
    ["infrastructure", ..] -> Infrastructure
    ["driver", "gleam", ..] -> Driver(Driving(Gleam))
    ["driver", "http", ..] -> Driver(Driving(Http))
    ["driver", "skir", ..] -> Driver(Driving(Skir))
    ["driver", ..] -> Driver(Common)
    _ -> Domain
  }
}

fn categorize(path: String) -> Category {
  case string.split(path, "/") {
    ["catalog", ..tail] -> Bc(Catalog, categorize_layer(tail))
    ["collection", ..tail] -> Bc(Collection, categorize_layer(tail))
    ["inventory_planning", ..tail] ->
      Bc(InventoryPlanning, categorize_layer(tail))
    ["shared", ..tail] -> Shared(categorize_layer(tail))
    ["bootstrap", ..] -> Bootstrap
    ["tcg_card_collector"] -> Bootstrap
    ["gleam", ..] -> External(GleamLibs)
    ["mist", ..] -> External(MistLib)
    ["skir_client", ..] -> External(SkirLib)
    ["simplifile", ..] -> External(Simplifile)
    x -> panic as { "Unknown path: " <> string.join(x, "/") }
  }
}

fn allowed_layers(layer: Layer) -> List(Layer) {
  case layer {
    Domain -> [Domain]
    Application -> [Domain, Application]
    Infrastructure -> [Domain, Application, Infrastructure]
    Driver(driver) -> [Domain, Application, Driver(driver), Driver(Common)]
  }
}

fn allowed_externals(layer: Layer) -> List(External) {
  case layer {
    Domain -> []
    Application -> []
    Infrastructure -> [Simplifile]
    Driver(Common) -> []
    Driver(Driving(Http)) -> [MistLib]
    Driver(Driving(Gleam)) -> []
    Driver(Driving(Skir)) -> [SkirLib]
  }
}

fn is_allowed(
  allowed_cross_bc: List(#(BoundedContext, BoundedContext)),
  from: Category,
  to: Category,
) -> Bool {
  case from, to {
    // Every category can import stuff from itself
    from, to if from == to -> True
    // Inside of the same context, we check if the layer is allowed
    Bc(from_ctx, from_layer), Bc(to_ctx, to_layer) if from_ctx == to_ctx ->
      list.contains(allowed_layers(from_layer), to_layer)
    Shared(from_layer), Shared(to_layer) ->
      list.contains(allowed_layers(from_layer), to_layer)
    // Bcs can use the layer correspondend shared types
    Bc(_, from_layer), Shared(to_layer) ->
      list.contains(allowed_layers(from_layer), to_layer)
    // Bootstrap is also allowed to use stuff from shared and bcs
    Bootstrap, Bc(_, _) | Bootstrap, Shared(_) -> True
    // Specific allowed cross-bounded-context dependencies
    Bc(from_bc, Infrastructure), Bc(to_bc, Driver(Driving(Gleam))) ->
      list.contains(allowed_cross_bc, #(from_bc, to_bc))
    _, External(GleamLibs) -> True
    Bootstrap, External(_) -> True
    Bc(_, layer), External(ext) | Shared(layer), External(ext) ->
      list.contains(allowed_externals(layer), ext)
    _, _ -> False
  }
}

fn describe_layer(layer: Layer) -> String {
  case layer {
    Domain -> "Domain"
    Application -> "Application"
    Infrastructure -> "Infrastructure"
    Driver(Common) -> "Driver(Common)"
    Driver(Driving(Http)) -> "Driver(Http)"
    Driver(Driving(Gleam)) -> "Driver(Gleam)"
    Driver(Driving(Skir)) -> "Driver(Skir)"
  }
}

fn describe_bc(bc: BoundedContext, layer: Layer) -> String {
  let bc_str = case bc {
    Catalog -> "Catalog"
    Collection -> "Collection"
    InventoryPlanning -> "InventoryPlanning"
  }
  "BoundedContext(" <> bc_str <> ", " <> describe_layer(layer) <> ")"
}

fn describe_external(ext: External) -> String {
  case ext {
    GleamLibs -> "GleamLibs"
    MistLib -> "MistLib"
    SkirLib -> "SkirLib"
    Simplifile -> "Simplifile"
  }
}

fn describe(cat: Category) -> String {
  case cat {
    Bc(bc, layer) -> describe_bc(bc, layer)
    Shared(layer) -> "Shared(" <> describe_layer(layer) <> ")"
    Bootstrap -> "Bootstrap"
    External(ext) -> "External(" <> describe_external(ext) <> ")"
  }
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

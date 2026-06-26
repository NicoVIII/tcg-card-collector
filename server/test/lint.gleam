import glinter
import rules/depends_only_on
import source_map

pub fn main() {
  let sm = source_map.build("./src")
  let config =
    depends_only_on.Config(allowed_cross_bc: [
      #(depends_only_on.InventoryPlanning, depends_only_on.Catalog),
      #(depends_only_on.InventoryPlanning, depends_only_on.Collection),
    ])
  glinter.run(extra_rules: [depends_only_on.rule(sm, config)])
}

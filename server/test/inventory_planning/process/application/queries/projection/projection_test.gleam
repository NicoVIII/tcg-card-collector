import gleam/dict
import gleam/list
import inventory_planning/application/queries/projection/handler
import inventory_planning/application/queries/projection/ports

// Ties the fakes to the handler's driving port. The catalog fake returns only
// the requested keys, mirroring the real batch lookup's "absent = unknown".
fn build_ports(
  snapshot snapshot: List(ports.SnapshotRow),
  catalog catalog: List(#(#(String, String), ports.CatalogAttributes)),
  rules rules: ports.RulesModel,
) -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: fn() { Ok(snapshot) },
    catalog_attributes: fn(keys) {
      catalog
      |> list.filter(fn(entry) { list.contains(keys, entry.0) })
      |> dict.from_list
    },
    rules: fn() { rules },
  )
}

fn attrs(
  name name: String,
  rarity rarity: String,
  oracle oracle: String,
  color color: String,
  type_line type_line: String,
  released released: String,
) -> ports.CatalogAttributes {
  ports.CatalogAttributes(
    name: name,
    rarity: rarity,
    oracle_id: oracle,
    color_identity: color,
    type_line: type_line,
    released_at: released,
  )
}

// The owner's real scheme, trimmed to two oracle ids across four printings:
//   - Lightning Bolt (rare, red): old LEA printing + newer M11 printing
//   - Grizzly Bears (common, green): M10 printing + newer M11 printing
// with the four-tier cascade (set binder / rare color binder / c+u color box /
// bulk). This single expected value pins membership, cascade ordering, quantity
// conservation, and the oldest-printing preference all at once.
fn sample_ports() -> ports.InventoryProjectionPorts {
  build_ports(
    snapshot: [
      ports.SnapshotRow(set_code: "lea", collector_number: "161", quantity: 1),
      ports.SnapshotRow(set_code: "m11", collector_number: "146", quantity: 3),
      ports.SnapshotRow(set_code: "m10", collector_number: "175", quantity: 1),
      ports.SnapshotRow(set_code: "m11", collector_number: "182", quantity: 1),
    ],
    catalog: [
      #(
        #("lea", "161"),
        attrs(
          name: "Lightning Bolt",
          rarity: "rare",
          oracle: "o-bolt",
          color: "R",
          type_line: "Instant",
          released: "1993-08-05",
        ),
      ),
      #(
        #("m11", "146"),
        attrs(
          name: "Lightning Bolt",
          rarity: "rare",
          oracle: "o-bolt",
          color: "R",
          type_line: "Instant",
          released: "2010-07-16",
        ),
      ),
      #(
        #("m10", "175"),
        attrs(
          name: "Grizzly Bears",
          rarity: "common",
          oracle: "o-bear",
          color: "G",
          type_line: "Creature — Bear",
          released: "2009-07-17",
        ),
      ),
      #(
        #("m11", "182"),
        attrs(
          name: "Grizzly Bears",
          rarity: "common",
          oracle: "o-bear",
          color: "G",
          type_line: "Creature — Bear",
          released: "2010-07-16",
        ),
      ),
    ],
    rules: ports.RulesModel(
      rules: [
        ports.RuleRow(
          id: "r-set",
          position: 0,
          selector: "first_per_printing",
          expression: "set_code in (lea)",
          location_name: "Binder {set_code}",
        ),
        ports.RuleRow(
          id: "r-rare",
          position: 1,
          selector: "first_per_oracle",
          expression: "rarity >= rare",
          location_name: "Rare binder {color_identity}",
        ),
        ports.RuleRow(
          id: "r-box",
          position: 2,
          selector: "first_per_oracle",
          expression: "rarity in (common, uncommon)",
          location_name: "Box {color_identity}",
        ),
      ],
      bulk: ports.BulkSpecRow(
        location_name: "Bulk",
        sort_keys: "color_identity,type,name",
      ),
    ),
  )
}

pub fn four_rule_cascade_places_every_copy_test() {
  let result = handler.execute(handler.InventoryProjectionQuery, sample_ports())

  assert result
    == Ok(
      ports.Projection(unknown_count: 0, total_quantity: 6, locations: [
        // Tier 1: the first LEA copy, oldest printing of the bolt.
        ports.ProjectionLocation(
          location_name: "Binder lea",
          rule_id: "r-set",
          total_quantity: 1,
          cards: [
            ports.ProjectionCard(
              name: "Lightning Bolt",
              set_code: "lea",
              collector_number: "161",
              quantity: 1,
              color_identity: "R",
              rarity: "rare",
              card_type: "instant",
            ),
          ],
        ),
        // Tier 2: next first-per-oracle rare copy — the LEA bolt is spent, so
        // this is the M11 bolt.
        ports.ProjectionLocation(
          location_name: "Rare binder R",
          rule_id: "r-rare",
          total_quantity: 1,
          cards: [
            ports.ProjectionCard(
              name: "Lightning Bolt",
              set_code: "m11",
              collector_number: "146",
              quantity: 1,
              color_identity: "R",
              rarity: "rare",
              card_type: "instant",
            ),
          ],
        ),
        // Tier 3: first-per-oracle common — prefers the older M10 bear.
        ports.ProjectionLocation(
          location_name: "Box G",
          rule_id: "r-box",
          total_quantity: 1,
          cards: [
            ports.ProjectionCard(
              name: "Grizzly Bears",
              set_code: "m10",
              collector_number: "175",
              quantity: 1,
              color_identity: "G",
              rarity: "common",
              card_type: "creature",
            ),
          ],
        ),
        // Bulk: the 2 leftover M11 bolts (1/1/2 split) and the leftover M11
        // bear, ordered red-instant before green-creature.
        ports.ProjectionLocation(
          location_name: "Bulk",
          rule_id: "",
          total_quantity: 3,
          cards: [
            ports.ProjectionCard(
              name: "Lightning Bolt",
              set_code: "m11",
              collector_number: "146",
              quantity: 2,
              color_identity: "R",
              rarity: "rare",
              card_type: "instant",
            ),
            ports.ProjectionCard(
              name: "Grizzly Bears",
              set_code: "m11",
              collector_number: "182",
              quantity: 1,
              color_identity: "G",
              rarity: "common",
              card_type: "creature",
            ),
          ],
        ),
      ]),
    )
}

pub fn unparseable_rule_propagates_as_error_test() {
  let ports =
    build_ports(
      snapshot: [],
      catalog: [],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "bad",
            position: 0,
            selector: "all",
            expression: "rarity >= legendary",
            location_name: "Nowhere",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  assert handler.execute(handler.InventoryProjectionQuery, ports)
    == Error("invalid rule expression: rarity >= legendary")
}

pub fn keys_missing_from_catalog_are_counted_and_bulked_test() {
  let ports =
    build_ports(
      snapshot: [
        ports.SnapshotRow(set_code: "xyz", collector_number: "1", quantity: 2),
      ],
      catalog: [],
      rules: ports.RulesModel(
        rules: [],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  assert handler.execute(handler.InventoryProjectionQuery, ports)
    == Ok(
      ports.Projection(unknown_count: 1, total_quantity: 2, locations: [
        ports.ProjectionLocation(
          location_name: "Bulk",
          rule_id: "",
          total_quantity: 2,
          cards: [
            ports.ProjectionCard(
              name: "",
              set_code: "xyz",
              collector_number: "1",
              quantity: 2,
              color_identity: "",
              rarity: "",
              card_type: "",
            ),
          ],
        ),
      ]),
    )
}

pub fn snapshot_rows_failure_propagates_as_error_test() {
  let ports =
    ports.InventoryProjectionPorts(
      snapshot_rows: fn() { Error("db unavailable") },
      catalog_attributes: fn(_keys) { dict.new() },
      rules: fn() {
        ports.RulesModel(
          rules: [],
          bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
        )
      },
    )

  assert handler.execute(handler.InventoryProjectionQuery, ports)
    == Error("db unavailable")
}

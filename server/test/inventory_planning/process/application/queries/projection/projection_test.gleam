import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import inventory_planning/application/queries/projection/handler
import inventory_planning/application/queries/projection/ports
import shared/domain/color_identity
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date

// Ties the fakes to the handler's driving port. The catalog fake returns only
// the requested keys, mirroring the real batch lookup's "absent = unknown".
fn build_ports(
  snapshot snapshot: List(ports.SnapshotRow),
  catalog catalog: List(#(#(String, String), ports.CatalogAttributes)),
  rules rules: ports.RulesModel,
) -> ports.InventoryProjectionPorts {
  build_ports_with_dates(snapshot:, catalog:, rules:, set_dates: [])
}

fn build_ports_with_dates(
  snapshot snapshot: List(ports.SnapshotRow),
  catalog catalog: List(#(#(String, String), ports.CatalogAttributes)),
  rules rules: ports.RulesModel,
  set_dates set_dates: List(#(String, String)),
) -> ports.InventoryProjectionPorts {
  ports.InventoryProjectionPorts(
    snapshot_rows: fn() { Ok(snapshot) },
    catalog_attributes: fn(keys) {
      catalog
      |> list.filter(fn(entry) { list.contains(keys, entry.0) })
      |> dict.from_list
      |> Ok
    },
    rules: fn() { Ok(rules) },
    set_metadata: fn(_codes) {
      set_dates
      |> list.map(fn(entry) {
        let #(code, raw_date) = entry
        #(code, set_meta(raw_date, ""))
      })
      |> dict.from_list
      |> Ok
    },
  )
}

// "" means unknown (None); anything else must be a valid ISO date.
fn date(raw: String) -> option.Option(release_date.ReleaseDate) {
  case raw {
    "" -> None
    _ -> {
      let assert Ok(parsed) = release_date.parse(raw)
      Some(parsed)
    }
  }
}

// "" parent means a root set.
fn set_meta(raw_date: String, parent: String) -> ports.SetMetadataRow {
  ports.SetMetadataRow(
    released_at: date(raw_date),
    parent_set_code: case parent {
      "" -> None
      _ -> Some(parent)
    },
  )
}

fn attrs(
  name name: String,
  rarity rarity_raw: String,
  oracle oracle: String,
  color color: String,
  type_line type_line: String,
  released released: String,
) -> ports.CatalogAttributes {
  let assert Ok(rarity_value) = rarity.parse(rarity_raw)
  let assert Ok(colors) = color_identity.parse(color)
  ports.CatalogAttributes(
    name: name,
    rarity: rarity_value,
    oracle_id: option.from_result(oracle_id.new(oracle)),
    color_identity: colors,
    type_line: type_line,
    released_at: date(released),
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
          sort_keys: "",
        ),
        ports.RuleRow(
          id: "r-rare",
          position: 1,
          selector: "first_per_oracle",
          expression: "rarity >= rare",
          location_name: "Rare binder {color_identity}",
          sort_keys: "",
        ),
        ports.RuleRow(
          id: "r-box",
          position: 2,
          selector: "first_per_oracle",
          expression: "rarity in (common, uncommon)",
          location_name: "Box {color_identity}",
          sort_keys: "",
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
            sort_keys: "",
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

// A rule's sort keys reorder the cards within its location — here by name, so
// the alphabetically-first card leads despite being the newer printing.
pub fn rule_sort_keys_order_cards_within_location_test() {
  let ports =
    build_ports(
      snapshot: [
        ports.SnapshotRow(set_code: "aaa", collector_number: "1", quantity: 1),
        ports.SnapshotRow(set_code: "bbb", collector_number: "2", quantity: 1),
      ],
      catalog: [
        #(
          #("aaa", "1"),
          attrs(
            name: "Zebra",
            rarity: "common",
            oracle: "o-zebra",
            color: "R",
            type_line: "Creature",
            released: "2000-01-01",
          ),
        ),
        #(
          #("bbb", "2"),
          attrs(
            name: "Apple",
            rarity: "common",
            oracle: "o-apple",
            color: "R",
            type_line: "Creature",
            released: "2001-01-01",
          ),
        ),
      ],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "shelf",
            position: 0,
            selector: "all",
            expression: "rarity >= common",
            location_name: "Shelf",
            sort_keys: "name",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, ports)
  let assert [location] = projection.locations
  assert location.location_name == "Shelf"
  assert list.map(location.cards, fn(c) { c.name }) == ["Apple", "Zebra"]
}

pub fn invalid_stored_rule_sort_keys_propagate_as_error_test() {
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
            expression: "rarity >= rare",
            location_name: "Nowhere",
            sort_keys: "power",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  assert handler.execute(handler.InventoryProjectionQuery, ports)
    == Error("invalid rule sort keys: power")
}

// set_metadata port feeds through to bucket ordering: two sets whose dates
// reverse alphabetical order end up in date order in the projection.
pub fn set_dates_port_wired_to_bucket_ordering_test() {
  let p =
    build_ports_with_dates(
      snapshot: [
        ports.SnapshotRow(set_code: "zzz", collector_number: "1", quantity: 1),
        ports.SnapshotRow(set_code: "aaa", collector_number: "2", quantity: 1),
      ],
      catalog: [
        #(
          #("zzz", "1"),
          attrs(
            name: "Old Card",
            rarity: "common",
            oracle: "o-old",
            color: "R",
            type_line: "Creature",
            released: "2000-01-01",
          ),
        ),
        #(
          #("aaa", "2"),
          attrs(
            name: "New Card",
            rarity: "common",
            oracle: "o-new",
            color: "R",
            type_line: "Creature",
            released: "2010-01-01",
          ),
        ),
      ],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "r-sets",
            position: 0,
            selector: "all",
            expression: "rarity >= common",
            location_name: "Binder {set_code}",
            sort_keys: "",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
      // Dict dates reverse alphabetical: zzz is older than aaa
      set_dates: [#("zzz", "2000-01-01"), #("aaa", "2010-01-01")],
    )
  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, p)
  let names = list.map(projection.locations, fn(l) { l.location_name })
  // Date order: zzz (2000) before aaa (2010), even though "aaa" < "zzz" alphabetically
  assert names == ["Binder zzz", "Binder aaa"]
}

pub fn snapshot_rows_failure_propagates_as_error_test() {
  let ports =
    ports.InventoryProjectionPorts(
      snapshot_rows: fn() { Error("db unavailable") },
      catalog_attributes: fn(_keys) { Ok(dict.new()) },
      rules: fn() {
        Ok(ports.RulesModel(
          rules: [],
          bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
        ))
      },
      set_metadata: fn(_codes) { Ok(dict.new()) },
    )

  assert handler.execute(handler.InventoryProjectionQuery, ports)
    == Error("db unavailable")
}

// A broken rules read must surface as an error — not an empty cascade that
// silently sweeps the whole collection into bulk (the #43 worst case).
pub fn rules_failure_propagates_as_error_test() {
  let ports =
    ports.InventoryProjectionPorts(
      snapshot_rows: fn() { Ok([]) },
      catalog_attributes: fn(_keys) { Ok(dict.new()) },
      rules: fn() { Error("rules table unreadable") },
      set_metadata: fn(_codes) { Ok(dict.new()) },
    )

  assert handler.execute(handler.InventoryProjectionQuery, ports)
    == Error("rules table unreadable")
}

// The set-metadata fetch follows parent links across rounds: the owned cards are
// tokens whose parent sets are unowned, so the parents' metadata is only served
// on the *second* request (the fake returns exactly the codes asked for). The
// families end up ordered by their root's release date — which the handler can
// only know if it re-requested the parents; the token dates alone would reverse
// the order.
pub fn set_metadata_transitive_fetch_reaches_unowned_parent_test() {
  let p =
    ports.InventoryProjectionPorts(
      snapshot_rows: fn() {
        Ok([
          ports.SnapshotRow(
            set_code: "tgrn",
            collector_number: "1",
            quantity: 1,
          ),
          ports.SnapshotRow(
            set_code: "twar",
            collector_number: "1",
            quantity: 1,
          ),
        ])
      },
      catalog_attributes: fn(keys) {
        [
          #(
            #("tgrn", "1"),
            attrs(
              name: "Saproling",
              rarity: "common",
              oracle: "o-sap",
              color: "G",
              type_line: "Creature — Saproling",
              released: "2019-01-01",
            ),
          ),
          #(
            #("twar", "1"),
            attrs(
              name: "Angel",
              rarity: "common",
              oracle: "o-ang",
              color: "W",
              type_line: "Creature — Angel",
              released: "2018-01-01",
            ),
          ),
        ]
        |> list.filter(fn(entry) { list.contains(keys, entry.0) })
        |> dict.from_list
        |> Ok
      },
      rules: fn() {
        Ok(ports.RulesModel(
          rules: [
            ports.RuleRow(
              id: "fam",
              position: 0,
              selector: "all",
              expression: "rarity >= common",
              location_name: "Binder {set_family}",
              sort_keys: "",
            ),
          ],
          bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
        ))
      },
      set_metadata: fn(codes) {
        // Token dates (tgrn 2019, twar 2018) reverse the root dates (grn 2018-10,
        // war 2019-05); grn/war are unowned so only appear on the second round.
        [
          #("tgrn", set_meta("2019-01-01", "grn")),
          #("twar", set_meta("2018-01-01", "war")),
          #("grn", set_meta("2018-10-05", "")),
          #("war", set_meta("2019-05-03", "")),
        ]
        |> list.filter(fn(entry) { list.contains(codes, entry.0) })
        |> dict.from_list
        |> Ok
      },
    )

  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, p)
  let names = list.map(projection.locations, fn(l) { l.location_name })
  assert names == ["Binder grn", "Binder war"]
}

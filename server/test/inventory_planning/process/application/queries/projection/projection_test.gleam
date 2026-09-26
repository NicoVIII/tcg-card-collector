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
  attrs_with_layout(
    name:,
    rarity: rarity_raw,
    oracle:,
    color:,
    type_line:,
    released:,
    layout: None,
  )
}

// Every field attrs() has, plus layout — kept separate so the token-clause
// tests can set layout without threading None through every other call site.
fn attrs_with_layout(
  name name: String,
  rarity rarity_raw: String,
  oracle oracle: String,
  color color: String,
  type_line type_line: String,
  released released: String,
  layout layout: option.Option(String),
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
    cmc: None,
    layout: layout,
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
      ports.SnapshotRow(
        set_code: "lea",
        collector_number: "161",
        finish: "nonfoil",
        language: "en",
        quantity: 1,
      ),
      ports.SnapshotRow(
        set_code: "m11",
        collector_number: "146",
        finish: "nonfoil",
        language: "en",
        quantity: 3,
      ),
      ports.SnapshotRow(
        set_code: "m10",
        collector_number: "175",
        finish: "nonfoil",
        language: "en",
        quantity: 1,
      ),
      ports.SnapshotRow(
        set_code: "m11",
        collector_number: "182",
        finish: "nonfoil",
        language: "en",
        quantity: 1,
      ),
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
              finish: "nonfoil",
              language: "en",
              quantity: 1,
              color_identity: "R",
              rarity: "rare",
              card_type: "instant",
            ),
          ],
          // Empty rule sort_keys -> one undivided section (#138).
          sections: [ports.ProjectionSection(parts: [], card_count: 1)],
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
              finish: "nonfoil",
              language: "en",
              quantity: 1,
              color_identity: "R",
              rarity: "rare",
              card_type: "instant",
            ),
          ],
          sections: [ports.ProjectionSection(parts: [], card_count: 1)],
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
              finish: "nonfoil",
              language: "en",
              quantity: 1,
              color_identity: "G",
              rarity: "common",
              card_type: "creature",
            ),
          ],
          sections: [ports.ProjectionSection(parts: [], card_count: 1)],
        ),
        // Bulk: the 2 leftover M11 bolts (1/1/2 split) and the leftover M11
        // bear, ordered red-instant before green-creature. Only 3 copies —
        // well under the 18-copy section threshold, so the bulk spec's
        // sort_keys don't produce a divided label either.
        ports.ProjectionLocation(
          location_name: "Bulk",
          rule_id: "",
          total_quantity: 3,
          cards: [
            ports.ProjectionCard(
              name: "Lightning Bolt",
              set_code: "m11",
              collector_number: "146",
              finish: "nonfoil",
              language: "en",
              quantity: 2,
              color_identity: "R",
              rarity: "rare",
              card_type: "instant",
            ),
            ports.ProjectionCard(
              name: "Grizzly Bears",
              set_code: "m11",
              collector_number: "182",
              finish: "nonfoil",
              language: "en",
              quantity: 1,
              color_identity: "G",
              rarity: "common",
              card_type: "creature",
            ),
          ],
          sections: [ports.ProjectionSection(parts: [], card_count: 3)],
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
        ports.SnapshotRow(
          set_code: "xyz",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity: 2,
        ),
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
              finish: "nonfoil",
              language: "en",
              quantity: 2,
              color_identity: "",
              rarity: "",
              card_type: "",
            ),
          ],
          sections: [ports.ProjectionSection(parts: [], card_count: 2)],
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
        ports.SnapshotRow(
          set_code: "aaa",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
        ports.SnapshotRow(
          set_code: "bbb",
          collector_number: "2",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
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

// A `supertype = basic` rule claims a Basic Land row and leaves a same-typed
// nonbasic land to bulk — proves the handler wires attrs.type_line through
// reduce_supertypes, not just reduce_card_type (#115).
pub fn supertype_basic_rule_routes_basic_land_test() {
  let ports =
    build_ports(
      snapshot: [
        ports.SnapshotRow(
          set_code: "lea",
          collector_number: "288",
          finish: "nonfoil",
          language: "en",
          quantity: 4,
        ),
        ports.SnapshotRow(
          set_code: "grn",
          collector_number: "251",
          finish: "nonfoil",
          language: "en",
          quantity: 2,
        ),
      ],
      catalog: [
        #(
          #("lea", "288"),
          attrs(
            name: "Plains",
            rarity: "common",
            oracle: "o-plains",
            color: "",
            type_line: "Basic Land — Plains",
            released: "1993-08-05",
          ),
        ),
        #(
          #("grn", "251"),
          attrs(
            name: "Gateway Plaza",
            rarity: "common",
            oracle: "o-gate",
            color: "",
            type_line: "Land — Gate",
            released: "2018-10-05",
          ),
        ),
      ],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "r-basic",
            position: 0,
            selector: "all",
            expression: "type = land and supertype = basic",
            location_name: "Basics",
            sort_keys: "",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, ports)
  let assert [basics, bulk] = projection.locations
  assert basics.location_name == "Basics"
  assert basics.total_quantity == 4
  let assert [plains] = basics.cards
  assert plains.name == "Plains"

  assert bulk.location_name == "Bulk"
  assert bulk.total_quantity == 2
  let assert [gate] = bulk.cards
  assert gate.name == "Gateway Plaza"
}

// A `token = yes` rule claims every layout Scryfall marks as a token —
// including one in a parentless set like sld — and nothing else: not a
// normal creature, and not an art_series card whose type line also says
// "Token" (#135's acceptance case for "Card // Token Creature — Elemental").
pub fn token_yes_rule_claims_only_token_layouts_test() {
  let ports =
    build_ports(
      snapshot: [
        ports.SnapshotRow(
          set_code: "sld",
          collector_number: "1001",
          finish: "nonfoil",
          language: "en",
          quantity: 2,
        ),
        ports.SnapshotRow(
          set_code: "twar",
          collector_number: "5",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
        ports.SnapshotRow(
          set_code: "grn",
          collector_number: "173",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
        ports.SnapshotRow(
          set_code: "sta",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
      ],
      catalog: [
        #(
          #("sld", "1001"),
          attrs_with_layout(
            name: "Elf Warrior",
            rarity: "common",
            oracle: "o-elf-token",
            color: "G",
            type_line: "Token Creature — Elf Warrior",
            released: "2020-04-17",
            layout: Some("token"),
          ),
        ),
        #(
          #("twar", "5"),
          attrs_with_layout(
            name: "Vraska",
            rarity: "common",
            oracle: "o-vraska-emblem",
            color: "B",
            type_line: "Creature — Zombie // Land",
            released: "2019-05-03",
            layout: Some("double_faced_token"),
          ),
        ),
        #(
          #("grn", "173"),
          attrs_with_layout(
            name: "Azorius Guildmage",
            rarity: "uncommon",
            oracle: "o-guildmage",
            color: "WU",
            type_line: "Creature — Human Wizard",
            released: "2018-10-05",
            layout: Some("normal"),
          ),
        ),
        #(
          #("sta", "1"),
          attrs_with_layout(
            name: "Elemental",
            rarity: "common",
            oracle: "o-elemental-art",
            color: "",
            type_line: "Card // Token Creature — Elemental",
            released: "2021-04-23",
            layout: Some("art_series"),
          ),
        ),
      ],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "r-token",
            position: 0,
            selector: "all",
            expression: "token = yes",
            location_name: "Tokens",
            sort_keys: "",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, ports)
  let assert [tokens, bulk] = projection.locations
  assert tokens.location_name == "Tokens"
  assert tokens.total_quantity == 3
  // Canonical claim order sorts by released_at first (ADR 0013): the twar
  // token (2019) claims ahead of the sld token (2020), regardless of
  // snapshot order.
  assert list.map(tokens.cards, fn(c) { c.name }) == ["Vraska", "Elf Warrior"]

  assert bulk.location_name == "Bulk"
  assert bulk.total_quantity == 2
  // Bulk's fold builds assignments by prepending, so an empty bulk sort_keys
  // (Eq for every pair, stable sort is a no-op) leaves them in reverse
  // canonical order.
  assert list.map(bulk.cards, fn(c) { c.name })
    == ["Elemental", "Azorius Guildmage"]
}

// The negated form falls through the cascade for a card the catalog can't
// attest to yet (a missing row, or a row whose layout is still NULL because
// the catalog hasn't been reloaded since #135) — same gap handling as every
// other enrichment clause (ADR 0017), not a match for either token = yes or
// token = no.
pub fn token_no_rule_excludes_unknown_layout_test() {
  let ports =
    build_ports(
      snapshot: [
        ports.SnapshotRow(
          set_code: "grn",
          collector_number: "173",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
        ports.SnapshotRow(
          set_code: "xyz",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
      ],
      catalog: [
        #(
          #("grn", "173"),
          attrs_with_layout(
            name: "Azorius Guildmage",
            rarity: "uncommon",
            oracle: "o-guildmage",
            color: "WU",
            type_line: "Creature — Human Wizard",
            released: "2018-10-05",
            layout: Some("normal"),
          ),
        ),
        #(
          #("xyz", "1"),
          attrs_with_layout(
            name: "Not Yet Reloaded",
            rarity: "common",
            oracle: "o-not-reloaded",
            color: "",
            type_line: "Creature — Bear",
            released: "2020-01-01",
            layout: None,
          ),
        ),
      ],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "r-real",
            position: 0,
            selector: "all",
            expression: "token = no",
            location_name: "RealCards",
            sort_keys: "",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, ports)
  let assert [real_cards, bulk] = projection.locations
  assert real_cards.location_name == "RealCards"
  let assert [guildmage] = real_cards.cards
  assert guildmage.name == "Azorius Guildmage"

  assert bulk.location_name == "Bulk"
  let assert [not_reloaded] = bulk.cards
  assert not_reloaded.name == "Not Yet Reloaded"
}

// A `type = land` rule claims a real land but not an MDFC whose land is its
// *back* face — proves the handler reads card_type_from_type_line's front-face
// reduction (ADR 0018), not the whole stored type_line (#134).
pub fn land_rule_ignores_mdfc_back_face_test() {
  let ports =
    build_ports(
      snapshot: [
        ports.SnapshotRow(
          set_code: "grn",
          collector_number: "251",
          finish: "nonfoil",
          language: "en",
          quantity: 2,
        ),
        ports.SnapshotRow(
          set_code: "znr",
          collector_number: "158",
          finish: "nonfoil",
          language: "en",
          quantity: 3,
        ),
      ],
      catalog: [
        #(
          #("grn", "251"),
          attrs(
            name: "Gateway Plaza",
            rarity: "common",
            oracle: "o-gate",
            color: "",
            type_line: "Land — Gate",
            released: "2018-10-05",
          ),
        ),
        #(
          #("znr", "158"),
          attrs(
            name: "Bala Ged Recovery // Bala Ged Sanctuary",
            rarity: "uncommon",
            oracle: "o-bala-ged",
            color: "g",
            type_line: "Sorcery // Land",
            released: "2020-09-25",
          ),
        ),
      ],
      rules: ports.RulesModel(
        rules: [
          ports.RuleRow(
            id: "r-land",
            position: 0,
            selector: "all",
            expression: "type = land",
            location_name: "Lands",
            sort_keys: "",
          ),
        ],
        bulk: ports.BulkSpecRow(location_name: "Bulk", sort_keys: ""),
      ),
    )

  let assert Ok(projection) =
    handler.execute(handler.InventoryProjectionQuery, ports)
  let assert [lands, bulk] = projection.locations
  assert lands.location_name == "Lands"
  let assert [gate] = lands.cards
  assert gate.name == "Gateway Plaza"

  assert bulk.location_name == "Bulk"
  let assert [recovery] = bulk.cards
  assert recovery.name == "Bala Ged Recovery // Bala Ged Sanctuary"
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
        ports.SnapshotRow(
          set_code: "zzz",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
        ports.SnapshotRow(
          set_code: "aaa",
          collector_number: "2",
          finish: "nonfoil",
          language: "en",
          quantity: 1,
        ),
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
            finish: "nonfoil",
            language: "en",
            quantity: 1,
          ),
          ports.SnapshotRow(
            set_code: "twar",
            collector_number: "1",
            finish: "nonfoil",
            language: "en",
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

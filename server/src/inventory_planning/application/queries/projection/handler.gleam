import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/domain/bulk_spec
import inventory_planning/domain/card_attributes.{type PlannedCard}
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_target
import inventory_planning/domain/rule_cascade
import inventory_planning/domain/set_index
import inventory_planning/domain/sort_spec
import shared/domain/card_key
import shared/domain/rarity

pub type InventoryProjectionQuery {
  InventoryProjectionQuery
}

pub fn execute(
  _query: InventoryProjectionQuery,
  ports: projection_ports.InventoryProjectionPorts,
) -> Result(projection_ports.Projection, String) {
  // A rule that no longer parses is a configuration error, not a card to drop:
  // surface it rather than silently omit placements the user expects. A broken
  // rules read is likewise an error, not an empty cascade that bulks everything.
  use rules_model <- result.try(ports.rules())
  use cascade <- result.try(build_cascade(rules_model))
  use snapshot_rows <- result.try(ports.snapshot_rows())

  use attributes <- result.try(
    ports.catalog_attributes(
      list.map(snapshot_rows, fn(row) { #(row.set_code, row.collector_number) }),
    ),
  )

  let planned = list.filter_map(snapshot_rows, plan_card(_, attributes))
  let unknown_count =
    list.count(snapshot_rows, fn(row) {
      dict.get(attributes, #(row.set_code, row.collector_number))
      |> result.is_error
    })

  let set_codes =
    list.map(planned, fn(c) { card_key.set_code_string(c.key) })
    |> list.unique
  use sets <- result.try(fetch_set_index(ports.set_metadata, set_codes))

  let locations =
    rule_cascade.project(cascade, planned, sets)
    |> list.map(to_location)

  Ok(projection_ports.Projection(
    locations: locations,
    total_quantity: list.fold(locations, 0, fn(sum, l) {
      sum + l.total_quantity
    }),
    unknown_count: unknown_count,
  ))
}

// --- Set-family index -----------------------------------------------------

// A parent set (e.g. a token set's `grn`) may itself be unowned and so absent
// from the first fetch, so we follow parent links round by round until no new
// parent appears. `dict.has_key` filtering already terminates a corrupt parent
// cycle; the round cap is a belt-and-braces bound (parent chains are ~1 deep
// today, so this is one extra round trip at most).
const max_parent_rounds = 5

fn fetch_set_index(
  port: projection_ports.SetMetadataPort,
  set_codes: List(String),
) -> Result(set_index.SetIndex, String) {
  fetch_set_index_loop(port, set_codes, dict.new(), max_parent_rounds)
}

fn fetch_set_index_loop(
  port: projection_ports.SetMetadataPort,
  to_fetch: List(String),
  acc: Dict(String, projection_ports.SetMetadataRow),
  fuel: Int,
) -> Result(set_index.SetIndex, String) {
  let fresh = list.filter(to_fetch, fn(code) { !dict.has_key(acc, code) })
  case fresh, fuel <= 0 {
    [], _ -> Ok(to_set_index(acc))
    _, True -> Ok(to_set_index(acc))
    _, False -> {
      use fetched <- result.try(port(fresh))
      let acc = dict.merge(acc, fetched)
      let parents =
        dict.values(fetched)
        |> list.filter_map(fn(row) {
          option.to_result(row.parent_set_code, Nil)
        })
        |> list.unique
      fetch_set_index_loop(port, parents, acc, fuel - 1)
    }
  }
}

fn to_set_index(
  rows: Dict(String, projection_ports.SetMetadataRow),
) -> set_index.SetIndex {
  dict.map_values(rows, fn(_code, row) {
    set_index.SetMeta(
      released_at: row.released_at,
      parent_set_code: row.parent_set_code,
    )
  })
}

// --- Cascade assembly -----------------------------------------------------

fn build_cascade(
  model: projection_ports.RulesModel,
) -> Result(rule_cascade.RuleCascade, String) {
  use rules <- result.try(list.try_map(model.rules, parse_rule))
  use sort_keys <- result.try(
    sort_spec.parse_sort_keys(model.bulk.sort_keys)
    |> result.replace_error("invalid bulk sort keys: " <> model.bulk.sort_keys),
  )
  Ok(rule_cascade.RuleCascade(
    rules: rules,
    bulk: bulk_spec.BulkSpec(
      location_name: model.bulk.location_name,
      sort_keys: sort_keys,
    ),
  ))
}

fn parse_rule(
  row: projection_ports.RuleRow,
) -> Result(rule_cascade.CascadeRule, String) {
  use selector <- result.try(
    copy_selector.parse(row.selector)
    |> result.replace_error("invalid rule selector: " <> row.selector),
  )
  use predicate <- result.try(
    card_predicate.parse(row.expression)
    |> result.replace_error("invalid rule expression: " <> row.expression),
  )
  use sort_keys <- result.try(
    sort_spec.parse_sort_keys(row.sort_keys)
    |> result.replace_error("invalid rule sort keys: " <> row.sort_keys),
  )
  Ok(rule_cascade.CascadeRule(
    id: row.id,
    position: row.position,
    selector: selector,
    predicate: predicate,
    target: location_target.parse(row.location_name),
    sort_keys: sort_keys,
  ))
}

// --- Card assembly --------------------------------------------------------

fn plan_card(
  row: projection_ports.SnapshotRow,
  attributes: Dict(#(String, String), projection_ports.CatalogAttributes),
) -> Result(PlannedCard, Nil) {
  // The snapshot stores canonical keys, so this only fails on corrupt data — a
  // row we genuinely cannot place, hence dropped.
  use key <- result.try(
    card_key.from_user_input(
      set_code: row.set_code,
      collector_number: row.collector_number,
    )
    |> result.replace_error(Nil),
  )

  let found = dict.get(attributes, #(row.set_code, row.collector_number))
  Ok(case found {
    Error(_) ->
      card_attributes.PlannedCard(
        key: key,
        name: "",
        quantity: row.quantity,
        released_at: None,
        oracle_id: None,
        rarity: None,
        color_identity: None,
        card_type: None,
      )
    Ok(attrs) ->
      card_attributes.PlannedCard(
        key: key,
        name: attrs.name,
        quantity: row.quantity,
        released_at: attrs.released_at,
        oracle_id: attrs.oracle_id,
        rarity: Some(attrs.rarity),
        color_identity: Some(attrs.color_identity),
        card_type: reduce_card_type(attrs.type_line),
      )
  })
}

// The type-line reduction is planning policy over the catalog's raw fact. An
// empty type_line is a catalog gap (multi-face layouts), not a real type, so it
// stays None (and the card fails `type = ...` predicates).
fn reduce_card_type(type_line: String) -> Option(card_attributes.CardType) {
  case type_line {
    "" -> None
    _ -> Some(card_attributes.card_type_from_type_line(type_line))
  }
}

// --- Bucket mapping -------------------------------------------------------

fn to_location(
  bucket: rule_cascade.LocationBucket,
) -> projection_ports.ProjectionLocation {
  projection_ports.ProjectionLocation(
    location_name: bucket.location_name,
    rule_id: option.unwrap(bucket.rule_id, ""),
    total_quantity: bucket.total_quantity,
    cards: list.map(bucket.cards, to_card),
  )
}

fn to_card(
  assignment: rule_cascade.Assignment,
) -> projection_ports.ProjectionCard {
  let card = assignment.card
  projection_ports.ProjectionCard(
    name: card.name,
    set_code: card_key.set_code_string(card.key),
    collector_number: card_key.collector_number_string(card.key),
    quantity: assignment.quantity,
    color_identity: card.color_identity
      |> option.map(card_attributes.color_identity_label)
      |> option.unwrap(""),
    rarity: card.rarity
      |> option.map(rarity.to_string)
      |> option.unwrap(""),
    card_type: card.card_type
      |> option.map(card_attributes.card_type_to_string)
      |> option.unwrap(""),
  )
}

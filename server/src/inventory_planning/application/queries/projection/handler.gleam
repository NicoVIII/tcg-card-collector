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
import inventory_planning/domain/sort_spec
import shared/domain/card_key

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
  use set_dates <- result.try(ports.set_release_dates(set_codes))

  let locations =
    rule_cascade.project(cascade, planned, set_dates)
    |> list.map(to_location)

  Ok(projection_ports.Projection(
    locations: locations,
    total_quantity: list.fold(locations, 0, fn(sum, l) {
      sum + l.total_quantity
    }),
    unknown_count: unknown_count,
  ))
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
        released_at: "",
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
        oracle_id: optional_string(attrs.oracle_id),
        rarity: card_attributes.parse_rarity(attrs.rarity) |> option.from_result,
        color_identity: card_attributes.parse_color_identity(
          attrs.color_identity,
        )
          |> option.from_result,
        card_type: parse_card_type(attrs.type_line),
      )
  })
}

fn optional_string(raw: String) -> Option(String) {
  case raw {
    "" -> None
    _ -> Some(raw)
  }
}

// An empty type_line is a catalog gap, not a real type, so it stays None (and
// the card fails `type = ...` predicates); anything else maps to a card type.
fn parse_card_type(type_line: String) -> Option(card_attributes.CardType) {
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
      |> option.map(card_attributes.rarity_to_string)
      |> option.unwrap(""),
    card_type: card.card_type
      |> option.map(card_attributes.card_type_to_string)
      |> option.unwrap(""),
  )
}

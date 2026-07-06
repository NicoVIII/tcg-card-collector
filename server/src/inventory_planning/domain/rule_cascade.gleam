import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleam/string
import inventory_planning/domain/bulk_spec.{type BulkSpec}
import inventory_planning/domain/card_attributes.{type PlannedCard}
import inventory_planning/domain/card_predicate.{type Predicate}
import inventory_planning/domain/copy_selector.{type CopySelector}
import inventory_planning/domain/location_target.{type LocationTarget}
import inventory_planning/domain/sort_spec
import shared/domain/card_key

// One rule in the ordered waterfall. Rules are applied in `position` order and
// each consumes from what earlier rules left behind.
pub type CascadeRule {
  CascadeRule(
    id: String,
    position: Int,
    selector: CopySelector,
    predicate: Predicate,
    target: LocationTarget,
    sort_keys: List(sort_spec.SortKey),
  )
}

pub type RuleCascade {
  RuleCascade(rules: List(CascadeRule), bulk: BulkSpec)
}

// A single placement decision: `quantity` copies of `card` go to `location_name`
// on account of `rule_id` (None for the bulk remainder).
pub type Assignment {
  Assignment(
    location_name: String,
    rule_id: Option(String),
    card: PlannedCard,
    quantity: Int,
  )
}

pub type LocationBucket {
  LocationBucket(
    location_name: String,
    rule_id: Option(String),
    total_quantity: Int,
    cards: List(Assignment),
  )
}

// Runs the waterfall: every remaining copy of every card is placed exactly once,
// into the earliest rule that claims it, else into bulk. O(rules x cards).
pub fn project(
  cascade: RuleCascade,
  cards: List(PlannedCard),
  set_release_dates: Dict(String, String),
) -> List(LocationBucket) {
  // 1. Canonical order — "prefer the oldest printing" for first-copy rules.
  let ordered = list.sort(cards, by: compare_canonical)

  // 2. Remaining copies per printing. Summed, not overwritten, so quantity
  // conservation holds even if the input carries duplicate printing keys.
  let remaining0 =
    list.fold(ordered, dict.new(), fn(acc, card) {
      dict.upsert(acc, card_attributes.printing_key(card), fn(existing) {
        option.unwrap(existing, 0) + card.quantity
      })
    })

  // 3. Apply each rule in position order, threading the remaining pool.
  let sorted_rules =
    list.sort(cascade.rules, fn(a, b) { int.compare(a.position, b.position) })
  let #(remaining_final, rule_assignments_rev) =
    list.fold(sorted_rules, #(remaining0, []), fn(state, rule) {
      let #(remaining, acc) = state
      let #(remaining_next, assignments) = apply_rule(rule, ordered, remaining)
      #(remaining_next, [#(rule, assignments), ..acc])
    })
  let rule_assignments = list.reverse(rule_assignments_rev)

  // 4. Remainder -> bulk, sorted per the bulk spec.
  let bulk_assignments = build_bulk(cascade.bulk, ordered, remaining_final)

  // 5. Buckets: per-rule (fanned out by rendered name), then bulk last.
  let rule_buckets =
    list.flat_map(rule_assignments, fn(pair) {
      let #(rule, assignments) = pair
      buckets_for_rule(rule, assignments, set_release_dates)
    })
  let bulk_buckets = case bulk_assignments {
    [] -> []
    _ -> [
      LocationBucket(
        location_name: cascade.bulk.location_name,
        rule_id: None,
        total_quantity: total_quantity(bulk_assignments),
        cards: bulk_assignments,
      ),
    ]
  }
  list.append(rule_buckets, bulk_buckets)
}

fn apply_rule(
  rule: CascadeRule,
  ordered: List(PlannedCard),
  remaining: Dict(String, Int),
) -> #(Dict(String, Int), List(Assignment)) {
  let #(remaining_next, _claimed, assignments_rev) =
    list.fold(ordered, #(remaining, set.new(), []), fn(state, card) {
      let #(remaining, claimed, acc) = state
      let key = card_attributes.printing_key(card)
      let available = dict.get(remaining, key) |> result.unwrap(0)
      case available > 0 && card_predicate.matches(rule.predicate, card) {
        False -> state
        True ->
          case location_target.render(rule.target, card) {
            None -> state
            Some(location_name) ->
              claim(
                rule,
                card,
                key,
                location_name,
                available,
                remaining,
                claimed,
                acc,
              )
          }
      }
    })
  #(remaining_next, list.reverse(assignments_rev))
}

fn claim(
  rule: CascadeRule,
  card: PlannedCard,
  key: String,
  location_name: String,
  available: Int,
  remaining: Dict(String, Int),
  claimed: Set(String),
  acc: List(Assignment),
) -> #(Dict(String, Int), Set(String), List(Assignment)) {
  case copy_selector.identity(rule.selector, card) {
    // AllCopies: take every remaining copy, no per-identity gating.
    None -> {
      let assignment = Assignment(location_name, Some(rule.id), card, available)
      #(dict.insert(remaining, key, 0), claimed, [assignment, ..acc])
    }
    // First-copy: one copy per not-yet-claimed identity.
    Some(identity) ->
      case set.contains(claimed, identity) {
        True -> #(remaining, claimed, acc)
        False -> {
          let assignment = Assignment(location_name, Some(rule.id), card, 1)
          #(
            dict.insert(remaining, key, available - 1),
            set.insert(claimed, identity),
            [assignment, ..acc],
          )
        }
      }
  }
}

fn build_bulk(
  bulk: BulkSpec,
  ordered: List(PlannedCard),
  remaining: Dict(String, Int),
) -> List(Assignment) {
  // Threads the pool so a duplicated printing key drains it once instead of
  // emitting its remainder per occurrence.
  let #(_, assignments_rev) =
    list.fold(ordered, #(remaining, []), fn(state, card) {
      let #(remaining, acc) = state
      let key = card_attributes.printing_key(card)
      let available = dict.get(remaining, key) |> result.unwrap(0)
      case available > 0 {
        True -> #(dict.insert(remaining, key, 0), [
          Assignment(bulk.location_name, None, card, available),
          ..acc
        ])
        False -> state
      }
    })
  assignments_rev
  |> list.sort(fn(a, b) {
    sort_spec.compare_cards(bulk.sort_keys, a.card, b.card)
  })
}

// Bucket set date: prefer the catalog's table entry; fall back to the
// representative card's released_at (cards in a {set_code} bucket share the same
// set_code so their released_at is consistent), then to "" (sorts first).
fn set_date(
  set_code: String,
  card_released_at: String,
  set_dates: Dict(String, String),
) -> String {
  let from_dict = result.unwrap(dict.get(set_dates, set_code), "")
  case from_dict {
    "" -> card_released_at
    d -> d
  }
}

fn compare_by_attribute(
  attribute: location_target.TemplateAttribute,
  set_dates: Dict(String, String),
  l: Assignment,
  r: Assignment,
) -> order.Order {
  case attribute {
    location_target.SetCodeAttribute -> {
      let code_l = card_key.set_code_string(l.card.key)
      let code_r = card_key.set_code_string(r.card.key)
      let date_l = set_date(code_l, l.card.released_at, set_dates)
      let date_r = set_date(code_r, r.card.released_at, set_dates)
      order.break_tie(
        string.compare(date_l, date_r),
        string.compare(code_l, code_r),
      )
    }
    location_target.ColorIdentityAttribute ->
      sort_spec.compare_cards([sort_spec.ByColorIdentity], l.card, r.card)
    location_target.TypeAttribute ->
      sort_spec.compare_cards([sort_spec.ByCardType], l.card, r.card)
  }
}

fn compare_buckets(
  target: location_target.LocationTarget,
  set_dates: Dict(String, String),
  l: Assignment,
  r: Assignment,
) -> order.Order {
  case target {
    location_target.Fixed(_) -> string.compare(l.location_name, r.location_name)
    location_target.Template(_, attribute, _) ->
      order.break_tie(
        compare_by_attribute(attribute, set_dates, l, r),
        string.compare(l.location_name, r.location_name),
      )
  }
}

// A template rule fans out across the distinct location names it rendered;
// buckets are ordered semantically (set release date / WUBRG / type rank for
// templates, alphabetically for fixed targets), cards within a bucket by the
// rule's sort keys.
fn buckets_for_rule(
  rule: CascadeRule,
  assignments: List(Assignment),
  set_release_dates: Dict(String, String),
) -> List(LocationBucket) {
  let names = assignments |> list.map(fn(a) { a.location_name }) |> list.unique
  names
  |> list.sort(fn(name_a, name_b) {
    // All same-name assignments share the template attribute value; first is a
    // faithful representative for ordering.
    let rep_a = list.find(assignments, fn(a) { a.location_name == name_a })
    let rep_b = list.find(assignments, fn(a) { a.location_name == name_b })
    case rep_a, rep_b {
      Ok(a), Ok(b) -> compare_buckets(rule.target, set_release_dates, a, b)
      _, _ -> string.compare(name_a, name_b)
    }
  })
  |> list.map(fn(name) {
    let cards =
      assignments
      |> list.filter(fn(a) { a.location_name == name })
      |> list.sort(fn(a, b) {
        sort_spec.compare_cards(rule.sort_keys, a.card, b.card)
      })
    LocationBucket(
      location_name: name,
      rule_id: Some(rule.id),
      total_quantity: total_quantity(cards),
      cards:,
    )
  })
}

fn total_quantity(assignments: List(Assignment)) -> Int {
  list.fold(assignments, 0, fn(sum, a) { sum + a.quantity })
}

// "Prefer the oldest printing": released_at asc, then set_code, then
// collector_number. An empty released_at sorts first (treated as earliest).
fn compare_canonical(a: PlannedCard, b: PlannedCard) -> order.Order {
  order.break_tie(
    string.compare(a.released_at, b.released_at),
    order.break_tie(
      string.compare(
        card_key.set_code_string(a.key),
        card_key.set_code_string(b.key),
      ),
      string.compare(
        card_key.collector_number_string(a.key),
        card_key.collector_number_string(b.key),
      ),
    ),
  )
}

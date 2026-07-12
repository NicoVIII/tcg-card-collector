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
import inventory_planning/domain/set_index.{type SetIndex}
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
  sets: SetIndex,
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
      let #(remaining_next, assignments) =
        apply_rule(rule, ordered, remaining, sets)
      #(remaining_next, [#(rule, assignments), ..acc])
    })
  let rule_assignments = list.reverse(rule_assignments_rev)

  // 4. Remainder -> bulk, sorted per the bulk spec.
  let bulk_assignments = build_bulk(cascade.bulk, ordered, remaining_final)

  // 5. Buckets: per-rule (fanned out by rendered name), then bulk last.
  let rule_buckets =
    list.flat_map(rule_assignments, fn(pair) {
      let #(rule, assignments) = pair
      buckets_for_rule(rule, assignments, sets)
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
  sets: SetIndex,
) -> #(Dict(String, Int), List(Assignment)) {
  let #(remaining_next, _claimed, assignments_rev) =
    list.fold(ordered, #(remaining, set.new(), []), fn(state, card) {
      let #(remaining, claimed, acc) = state
      let key = card_attributes.printing_key(card)
      let available = dict.get(remaining, key) |> result.unwrap(0)
      case available > 0 && card_predicate.matches(rule.predicate, card) {
        False -> state
        True ->
          case location_target.render(rule.target, card, sets) {
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

// A fanned-out bucket with the facts ordering needs precomputed, so the sort
// comparator doesn't rescan the assignment list on every comparison. `sort_code`
// is the code that orders this bucket against its siblings — the family root for
// a {set_family} template, the witness's own set otherwise — and `set_date` is
// that code's release date. All same-name assignments share the template
// attribute value by construction, so the first is a faithful witness for
// color/type comparisons.
type FannedBucket {
  FannedBucket(
    name: String,
    witness: Assignment,
    sort_code: String,
    set_date: String,
    assignments: List(Assignment),
  )
}

// Bucket set date: prefer the catalog entry for the bucket's sort_code (so a
// {set_family} bucket dates off its root even when no root-set card is owned);
// fall back to the minimum non-empty released_at among the bucket's cards
// (card-level dates can vary within a set, e.g. promos), then to "" (sorts first).
fn bucket_set_date(
  sort_code: String,
  assignments: List(Assignment),
  sets: SetIndex,
) -> String {
  case set_index.release_date(sets, sort_code) {
    "" ->
      assignments
      |> list.filter_map(fn(a) {
        case a.card.released_at {
          "" -> Error(Nil)
          date -> Ok(date)
        }
      })
      |> list.sort(string.compare)
      |> list.first
      |> result.unwrap("")
    date -> date
  }
}

// The code a bucket sorts under: a {set_family} template collapses child sets
// (tokens, promos) onto their family root; every other target keeps its own set.
fn bucket_sort_code(
  target: LocationTarget,
  witness: Assignment,
  sets: SetIndex,
) -> String {
  let own = card_key.set_code_string(witness.card.key)
  case target {
    location_target.Template(_, location_target.SetFamilyAttribute, _) ->
      set_index.family_root(sets, own)
    _ -> own
  }
}

fn fanned_bucket(
  target: LocationTarget,
  name: String,
  assignments: List(Assignment),
  sets: SetIndex,
) -> Result(FannedBucket, Nil) {
  case assignments {
    [] -> Error(Nil)
    [witness, ..] -> {
      let sort_code = bucket_sort_code(target, witness, sets)
      Ok(FannedBucket(
        name:,
        witness:,
        sort_code:,
        set_date: bucket_set_date(sort_code, assignments, sets),
        assignments:,
      ))
    }
  }
}

fn compare_by_attribute(
  attribute: location_target.TemplateAttribute,
  l: FannedBucket,
  r: FannedBucket,
) -> order.Order {
  case attribute {
    // Family buckets sort exactly like set buckets, keyed on the root code/date.
    location_target.SetCodeAttribute | location_target.SetFamilyAttribute ->
      order.break_tie(
        string.compare(l.set_date, r.set_date),
        string.compare(l.sort_code, r.sort_code),
      )
    location_target.ColorIdentityAttribute ->
      sort_spec.compare_cards(
        [sort_spec.ByColorIdentity],
        l.witness.card,
        r.witness.card,
      )
    location_target.TypeAttribute ->
      sort_spec.compare_cards(
        [sort_spec.ByCardType],
        l.witness.card,
        r.witness.card,
      )
  }
}

fn compare_buckets(
  target: location_target.LocationTarget,
  l: FannedBucket,
  r: FannedBucket,
) -> order.Order {
  case target {
    location_target.Fixed(_) -> string.compare(l.name, r.name)
    location_target.Template(_, attribute, _) ->
      order.break_tie(
        compare_by_attribute(attribute, l, r),
        string.compare(l.name, r.name),
      )
  }
}

// Rank 0 for a root-set card, 1 for a child (token/promo): a card's own set is
// its family root only when it *is* the root.
fn family_rank(sets: SetIndex, card: PlannedCard) -> Int {
  let code = card_key.set_code_string(card.key)
  case set_index.family_root(sets, code) == code {
    True -> 0
    False -> 1
  }
}

// Within a {set_family} bucket: root-set cards first ("tokens at the back"),
// then children by release date, then set code. The rank comparison dominates,
// so root cards stay first even when a child set released earlier — intended;
// don't "fix" it to a plain date sort.
fn compare_family_group(
  sets: SetIndex,
  a: Assignment,
  b: Assignment,
) -> order.Order {
  order.break_tie(
    int.compare(family_rank(sets, a.card), family_rank(sets, b.card)),
    order.break_tie(
      string.compare(
        set_index.release_date(sets, card_key.set_code_string(a.card.key)),
        set_index.release_date(sets, card_key.set_code_string(b.card.key)),
      ),
      string.compare(
        card_key.set_code_string(a.card.key),
        card_key.set_code_string(b.card.key),
      ),
    ),
  )
}

// Orders cards within a bucket: the rule's sort keys, but a {set_family} rule
// first segregates root cards from child cards (sort keys break ties within each
// group).
fn within_bucket_comparator(
  rule: CascadeRule,
  sets: SetIndex,
) -> fn(Assignment, Assignment) -> order.Order {
  case rule.target {
    location_target.Template(_, location_target.SetFamilyAttribute, _) -> fn(
      a,
      b,
    ) {
      order.break_tie(
        compare_family_group(sets, a, b),
        sort_spec.compare_cards(rule.sort_keys, a.card, b.card),
      )
    }
    _ -> fn(a: Assignment, b: Assignment) {
      sort_spec.compare_cards(rule.sort_keys, a.card, b.card)
    }
  }
}

// A template rule fans out across the distinct location names it rendered;
// buckets are ordered semantically (set/family release date / WUBRG / type rank
// for templates, alphabetically for fixed targets), cards within a bucket by the
// rule's sort keys.
fn buckets_for_rule(
  rule: CascadeRule,
  assignments: List(Assignment),
  sets: SetIndex,
) -> List(LocationBucket) {
  let compare_cards = within_bucket_comparator(rule, sets)
  assignments
  |> list.map(fn(a) { a.location_name })
  |> list.unique
  |> list.filter_map(fn(name) {
    let bucket = list.filter(assignments, fn(a) { a.location_name == name })
    fanned_bucket(rule.target, name, bucket, sets)
  })
  |> list.sort(fn(l, r) { compare_buckets(rule.target, l, r) })
  |> list.map(fn(bucket) {
    let cards = list.sort(bucket.assignments, compare_cards)
    LocationBucket(
      location_name: bucket.name,
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

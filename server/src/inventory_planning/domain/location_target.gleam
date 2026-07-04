import gleam/option.{type Option, None, Some}
import gleam/string
import inventory_planning/domain/card_attributes.{type PlannedCard}
import shared/domain/card_key

// Where a rule sends the cards it claims. A Fixed target is a literal location
// name; a Template fans one rule out across many locations by interpolating a
// single card attribute (e.g. `binder {color_identity}`).
pub type LocationTarget {
  Fixed(name: String)
  Template(prefix: String, attribute: TemplateAttribute, suffix: String)
}

pub type TemplateAttribute {
  SetCodeAttribute
  ColorIdentityAttribute
  TypeAttribute
}

const placeholders = [
  #("{set_code}", SetCodeAttribute),
  #("{color_identity}", ColorIdentityAttribute),
  #("{type}", TypeAttribute),
]

// A location string with no known placeholder is a Fixed target; otherwise it
// splits into prefix/attribute/suffix around the first placeholder found.
pub fn parse(raw: String) -> LocationTarget {
  parse_loop(raw, placeholders)
}

fn parse_loop(
  raw: String,
  candidates: List(#(String, TemplateAttribute)),
) -> LocationTarget {
  case candidates {
    [] -> Fixed(raw)
    [#(token, attribute), ..rest] ->
      case string.split_once(raw, token) {
        Ok(#(prefix, suffix)) -> Template(prefix, attribute, suffix)
        Error(_) -> parse_loop(raw, rest)
      }
  }
}

fn attribute_token(attribute: TemplateAttribute) -> String {
  case attribute {
    SetCodeAttribute -> "{set_code}"
    ColorIdentityAttribute -> "{color_identity}"
    TypeAttribute -> "{type}"
  }
}

pub fn to_string(target: LocationTarget) -> String {
  case target {
    Fixed(name) -> name
    Template(prefix, attribute, suffix) ->
      prefix <> attribute_token(attribute) <> suffix
  }
}

// The concrete location for a card, or None when the template's attribute is
// missing on the card — in which case the rule does not claim the card.
pub fn render(target: LocationTarget, card: PlannedCard) -> Option(String) {
  case target {
    Fixed(name) -> Some(name)
    Template(prefix, attribute, suffix) ->
      case attribute_value(attribute, card) {
        Some(value) -> Some(prefix <> value <> suffix)
        None -> None
      }
  }
}

fn attribute_value(
  attribute: TemplateAttribute,
  card: PlannedCard,
) -> Option(String) {
  case attribute {
    SetCodeAttribute -> Some(card_key.set_code_string(card.key))
    ColorIdentityAttribute ->
      option.map(card.color_identity, card_attributes.color_identity_label)
    TypeAttribute ->
      option.map(card.card_type, card_attributes.card_type_to_string)
  }
}
